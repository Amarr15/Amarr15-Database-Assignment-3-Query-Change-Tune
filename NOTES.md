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
