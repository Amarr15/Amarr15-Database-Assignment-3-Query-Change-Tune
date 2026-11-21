# Database Assignment 3 — Query, Change & Tune Data

**Course:** Simulation Academy – .NET Diploma – Cycle 1  
**Student Name:** Ammar Yasser  
**Track:** Backend .NET  

---

## Task 6 — Reading the Plan

### 1. Expected Operators (Before running)
Before executing the query, I expected SQL Server to:
- Scan both `Invoices` and `StudentProfiles` tables.
- Join them using a Hash Match or Merge Join.
- Sort the joined results by `Remaining DESC`.
- Apply a Top operator to return the 15 rows.

---

### 2. Actual Execution Plan Analysis (From right to left)
Looking at the actual execution plan:

1. **Clustered Index Scan (`finance.Invoices`):**
   - **Cost:** 38%
   - It scanned the entire table (50,427 actual rows out of 43,582 estimated).
   - **Why SQL Server chose it:** There is no index covering the filter conditions (`DueAtUtc` and `PaidAmount < TotalAmount`), so it had to scan all rows in the clustered index. Notice the green missing index recommendation on `DueAtUtc`.

2. **Compute Scalar:**
   - Evaluated the expression `Remaining = TotalAmount - PaidAmount`.

3. **Sort:**
   - **Cost:** 60% (The most expensive operator in the plan).
   - It sorted the 50,427 filtered invoices descending by `Remaining`.
   - **Why SQL Server chose it:** The query requires `ORDER BY Remaining DESC`, and since `Remaining` is a computed column without an index, SQL Server had to sort the rows in memory.

4. **Nested Loops (Inner Join):**
   - **Cost:** 0%
   - It joined the top 15 invoices with `StudentProfiles`.

5. **Clustered Index Seek (`identity.StudentProfiles`):**
   - **Cost:** 1%
   - It performed 15 seeks directly on `PK_StudentProfiles` for only the 15 students who own the top invoices.
   - **Why SQL Server chose it:** The optimizer realized it only needed student details for the top 15 invoices, so it used a fast index seek for each one instead of scanning the whole student table.

6. **Top (15):**
   - Stopped processing once 15 rows were satisfied.

7. **Compute Scalar:**
   - Computed the `Urgency` column (`CASE WHEN DueAtUtc < ... THEN 'Urgent' ELSE 'Normal' END`) for the final 15 rows.

---

### 3. Where My Guess Was Wrong
I thought SQL Server would join all invoices with all students first and then sort. 

Instead, the optimizer was much smarter:
- It filtered and sorted the invoices **first**.
- Then it took the **Top 15** invoices.
- Finally, it only looked up `StudentProfiles` for those 15 records using a **Nested Loops Join** with an **Index Seek**.
- This saved thousands of lookups on the student table and kept logical reads on `StudentProfiles` down to only 173 reads.

---

### 4. Metrics
- **Table `finance.Invoices`:** 2,542 logical reads (full clustered index scan).
- **Table `identity.StudentProfiles`:** 173 logical reads (15 seeks).
- **Execution Time:** CPU time ~16 ms, Elapsed time ~95 ms.


---

## Task 7 — Make It Faster

Below is the explanation and logical reads comparison for each query before and after fixing the SARGability issues:

### 7.1 — Users who registered in March 2026
- **Problem:** Using `YEAR(CreatedAtUtc)` and `MONTH(CreatedAtUtc)` applies functions to the column, making it non-SARGable and forcing a full index scan.
- **Fix:** Used a date range (`>= '2026-03-01' AND < '2026-04-01'`).
- **Logical Reads:** Reduced from **455 reads** (Index Scan) to **13 reads** (Index Seek).

### 7.2 — Payments of the last 30 days
- **Problem:** `DATEDIFF(DAY, PaidAtUtc, SYSUTCDATETIME()) <= 30` prevents index usage because the indexed column is wrapped in `DATEDIFF`.
- **Fix:** Isolated the column on one side: `PaidAtUtc >= DATEADD(DAY, -30, SYSUTCDATETIME())`.
- **Logical Reads:** Reduced from **599 reads** to **76 reads**.

### 7.3 — Last names starting with "Abd"
- **Problem:** `LEFT(LastName, 3) = N'Abd'` prevents the optimizer from seeking into `IX_Users_LastName`.
- **Fix:** Replaced with `LastName LIKE N'Abd%'`.
- **Logical Reads:** Reduced from **1,267 reads** to **20 reads**.

### 7.4 — Math on Id in AuditLogs
- **Problem:** `Id + 1 = 50001` performs arithmetic on the clustered key, causing a full clustered scan over millions of rows.
- **Fix:** Simplified the math: `Id = 50000`.
- **Logical Reads:** Reduced from **127,092 reads** to **4 reads**.

### 7.5 — Implicit Conversion on InvoiceNumber
- **Problem:** `InvoiceNumber` is `VARCHAR(30)` while `N'LAB-INV-2026-000001'` is `NVARCHAR`. Due to data type precedence, SQL Server converted all column values (`CONVERT_IMPLICIT`), causing a scan with a warning.
- **Fix:** Removed the `N` prefix to match `VARCHAR`: `'LAB-INV-2026-000001'`.
- **Logical Reads:** Reduced from **725 reads** to **3 reads**.

### 7.6 — Case Insensitive Login Screen
- **Problem:** The database collation is already case-insensitive (`SQL_Latin1_General_CP1_CI_AS`), so `UPPER(Email)` was redundant and broke index seek.
- **Fix:** Removed `UPPER()` on both sides: `Email = @Email`.
- **Logical Reads:** Reduced from **1,009 reads** to **3 reads**.

### 7.7 — Optional Search Parameter
- **Problem:** `(@LastName IS NULL OR LastName = @LastName)` forced the optimizer to create a single plan that works for NULL, causing an index scan even when a name was supplied.
- **Fix:** Added `OPTION (RECOMPILE)` to generate an optimal plan for the supplied value.
- **Logical Reads:** Reduced from **1,267 reads** to **18 reads**.

### 7.8 — Custom Non-SARGable Example
- **Problem:** Wrapping `PaidAtUtc` with `CONVERT(VARCHAR(10), PaidAtUtc, 120) = '2026-10-15'` caused a scan on `IX_Payments_PaidAtUtc`.
- **Fix:** Rewrote using a half-open date range (`>= '2026-10-15' AND < '2026-10-16'`).
- **Logical Reads:** Reduced from **599 reads** to **3 reads**.


---

## Task 8 — When the Estimate Is Wrong (Tempdb Spill)

### 1. What Happened
The query sorted 100,000 rows from `dbo.LargeOrders`. SQL Server granted only **5,936 KB** of memory based on an estimated row count of 30,000 rows. 

Because the actual rows (100,000 rows) far exceeded the memory grant, memory was exhausted, and the `Sort` operator spilled to `tempdb` with a yellow warning triangle ⚠️:
> `Operator used tempdb to spill data during execution with spill level 1 and 1 spilled thread(s); Sort wrote 740 pages to and read 740 pages from tempdb with granted memory 5936KB and used memory 5936KB.`

### 2. Why It Happened
I used a local variable `@Cutoff` in the WHERE clause. SQL Server cannot sniff local variables at compile time, so it used a generic density vector estimate (30,000 rows) instead of the actual data distribution (100,000 rows).

### 3. What Spill Level Means
- **Spill Level 1:** SQL Server made a single write pass of the overflow data (740 pages) to `tempdb` and read it back once to complete the sort.
- Higher spill levels (like Level 2+) occur when even the spilled chunks do not fit in memory and require multiple recursive spill passes.

### 4. Why It Is Slow
Sorting in RAM operates in nanoseconds. Spilling to `tempdb` forces physical disk I/O (writing and reading pages from disk), which adds high disk latency and creates contention on tempdb.

### 5. How It Was Fixed
I added `OPTION (RECOMPILE)`. This allowed the optimizer to sniff the actual parameter value at execution time, estimating the exact 100,000 rows (100% accuracy). SQL Server granted sufficient memory, and the sort finished completely in memory with zero spills and no warnings.


---

## Task 9 — One of Each (Distinct Operators)

### 1. DISTINCT on an Unindexed Column
I executed `SELECT DISTINCT CurrencyCode FROM dbo.LargeOrders;`.
- **Operator Used:** **`Hash Match (Aggregate)`**.
- **How It Works:** SQL Server scans the unindexed table and builds an in-memory Hash Table. For each row, it hashes the `CurrencyCode`. If the hash entry already exists, the duplicate is discarded. If it is new, it is inserted into the hash bucket.

### 2. The Cheaper Duplicate Removal Operator
- **Operator Name:** **`Stream Aggregate`**.
- **How It Works:** It reads rows in a single pass with minimal memory overhead. Since data is pre-ordered, duplicates appear adjacent to each other. It compares each row only to the previous row: if identical, it ignores it; if different, it emits the distinct value.
- **Requirement:** It requires the input data to be **already sorted** on that column (e.g. by having an index on the column or after an explicit Sort).

### 3. DISTINCT on an Already Unique Column
When running `SELECT DISTINCT Id FROM finance.Invoices;` (or on a Primary Key / Unique column):
- **Plan Result:** There is **NO aggregation operator at all** (neither Hash Match nor Stream Aggregate).
- **Explanation:** SQL Server's query optimizer checks the table metadata. Since `Id` is already a Primary Key (guaranteed unique), deduplication is a no-op. The optimizer completely removes the DISTINCT operator and simply scans the index.


---

## Task 10 — The CTO's Question (Numbers vs GUIDs for IDs)

The trade-offs between sequential numbers (`INT`/`BIGINT IDENTITY`) and `GUID` (`UNIQUEIDENTIFIER`):

### 1. Sequential Numbers (`INT` / `BIGINT`)
- **Pros:**
  - **Storage:** Small footprint (4 bytes for `INT`, 8 bytes for `BIGINT`), keeping index and data pages compact.
  - **Performance:** Monotonically increasing values append to the end of the Clustered Index, eliminating page splits and fragmentation.
  - **Join Speed:** CPU-friendly integer comparisons make joins and lookups extremely fast.
- **Cons:**
  - **Centralized:** Requires a round-trip to the database server to generate the next ID (cannot generate IDs on client or offline).
  - **Security:** Predictable numbers make it easy for attackers to guess or enumerate records (e.g. `order/1001`, `order/1002`).
  - **Distributed Systems:** Merging data from multiple databases or branches leads to ID collisions.

### 2. GUIDs (`UNIQUEIDENTIFIER`)
- **Pros:**
  - **Distributed Generation:** Can be generated anywhere (clients, microservices, mobile apps) without contacting the database, with zero collision risk.
  - **Security:** Non-sequential and difficult to guess, protecting business volume and preventing enumeration attacks.
  - **Merging:** Easy to merge databases or replicate data across regions.
- **Cons:**
  - **Storage:** 16 bytes (double `BIGINT`), significantly increasing table and index sizes.
  - **Fragmentation:** Random GUIDs (`NEWID()`) cause heavy page splits and severe index fragmentation when used as clustered keys (partially mitigated with `NEWSEQUENTIALID()`).
  - **Performance:** Larger indexes mean fewer rows per page, requiring more memory and I/O.

### Recommendation:
- Use **`BIGINT IDENTITY`** for internal primary keys and clustered indexes to maximize performance and minimize storage.
- Use **`GUID`** as a public-facing business key (for APIs and URLs) or in distributed/offline systems where clients must generate IDs independently.
