-- Task 1 ó The Finance Meeting
-- 1.1 & 1.2
GO
SELECT 
    InvoiceNumber,
    StudentId,
    TotalAmount,
    PaidAmount,
    (TotalAmount - PaidAmount) AS RemainingAmount,
    DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) AS DaysLate,
    CASE 
        WHEN DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) > 60 OR (TotalAmount - PaidAmount) > 10000 THEN 'Urgent'
        WHEN DATEDIFF(DAY, DueAtUtc, SYSUTCDATETIME()) > 30 THEN 'Medium'
        ELSE 'Low'
    END AS Priority
INTO #LateInvoices
FROM finance.Invoices
WHERE DueAtUtc < SYSUTCDATETIME()
  AND PaidAmount < TotalAmount;
GO

-- 1.3
SELECT 
    InvoiceNumber,
    StudentId,
    TotalAmount,
    PaidAmount,
    RemainingAmount,
    DaysLate,
    Priority
FROM #LateInvoices
ORDER BY 
    CASE Priority
        WHEN 'Urgent' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
    END,
    RemainingAmount DESC;
GO


-- Task 2

--2.1
INSERT INTO academic.Departments
    (Code, Name, IsActive)
	
	VALUES
		('DSAI', N'Data Science & Artificial Intelligence', 1);

--2.2

INSERT INTO academic.Courses
	(DepartmentId,Code,Title,CreditHours,PassingScore,IsActive)
	
	VALUES
		((SELECT Id
     FROM academic.Departments
     WHERE Code = 'DSAI')
	 ,'DSAI-101',N'Introduction to Data Analysis',3,60,1);


--2.3

INSERT INTO delivery.AcademicTerms(
	AcademicYear,
	TermCode,
	Name,
	StartDate,
	EndDate,
	RegistrationStartDate,
	RegistrationEndDate,
	Status
	)
	VALUES(
	2027,
	'SUMMER',
	N'Summer 2027',
	'2027-06-15',
	'2027-08-31',
	'2027-05-01',
	'2027-06-10',
	2
	);

--2.4

INSERT INTO communication.Announcements
(
    SectionId,
    Title,
    Body,
    PublishedAtUtc,
    CreatedByUserId,
    Status
)
VALUES
(
    NULL,
    N'Summer 2027 Registration',
    N'Summer 2027 registration opens on 1 May.',
    SYSUTCDATETIME(),
    1,
    2
);

--2.5

INSERT INTO [identity].Roles
(
    Code,
    Name,
    IsSystem,
    IsDeleted
)
VALUES
(
    'TEACHING_ASSISTANT',
    N'Teaching Assistants',
    0,
    0
);


--3.1

GO

CREATE SEQUENCE finance.InvoiceNumberSeq
    AS INT
    START WITH 1
    INCREMENT BY 1;
GO

-- 3.2:
INSERT INTO finance.Invoices
(
    InvoiceNumber,
    StudentId,
    TermId,
    CurrencyCode,
    IssuedAtUtc,
    DueAtUtc,
    TotalAmount,
    PaidAmount,
    Status
)
VALUES
(
    'LAB-INV-2026-' + RIGHT('000000' + CAST(NEXT VALUE FOR finance.InvoiceNumberSeq AS VARCHAR(6)), 6),
    (SELECT TOP 1 Id FROM [identity].StudentProfiles),
    (SELECT TOP 1 Id FROM delivery.AcademicTerms),
    'EGP',
    SYSUTCDATETIME(),
    DATEADD(DAY, 30, SYSUTCDATETIME()),
    4500.00,
    0.00,
    1
);
GO

-- 3.3
BEGIN TRANSACTION;
    SELECT NEXT VALUE FOR finance.InvoiceNumberSeq AS NumberInsideCancelledTx;
ROLLBACK TRANSACTION;

SELECT NEXT VALUE FOR finance.InvoiceNumberSeq AS NextNumberAfterRollback;
GO


--4

INSERT INTO delivery.Sections
(
    CourseId,
    TermId,
    SectionCode,
    Capacity,
    Location,
    DeliveryMode,
    Status
)
SELECT 
    CourseId,
    (SELECT Id FROM delivery.AcademicTerms WHERE Name = 'Summer 2027'),
    SectionCode,
    Capacity,
    Location,
    DeliveryMode,
    Status
FROM delivery.Sections

WHERE TermId = (
    SELECT TOP 1 Id 
    FROM delivery.AcademicTerms 
    WHERE StartDate < '2027-06-15' AND Name <> 'Summer 2027'
    ORDER BY StartDate DESC
);
GO

SELECT *
FROM delivery.Sections
WHERE TermId = (SELECT Id FROM delivery.AcademicTerms WHERE Name = 'Summer 2027');
GO


--5.1

SELECT
    Code AS [Course Code],
    Title AS [Course Title],
    CreditHours AS [Credit Hours]
FROM academic.Courses
ORDER BY
    CreditHours DESC,
    Title ASC;

--5.2

SELECT TOP (5) *
FROM [identity].StudentProfiles
ORDER BY NEWID();

--5.3

SELECT
    Id,
    Email
FROM [identity].Users
WHERE DATALENGTH(Email) <> DATALENGTH(TRIM(Email))

--5.4

SELECT
    Id,
    Email
FROM [identity].Users
WHERE Email COLLATE Latin1_General_CS_AS <> LOWER(Email);

--5.5

SELECT
    Id,
    Email
FROM [identity].Users
WHERE
    Email NOT LIKE '%@%'
    OR Email LIKE '@%'
    OR Email NOT LIKE '%@%.%';

--5.6

SELECT DISTINCT
    SUBSTRING(
        Email,
        CHARINDEX('@', Email) + 1,
        LEN(Email)
    ) AS [Email Provider]
FROM [identity].Users
WHERE Email LIKE '%@%'
ORDER BY [Email Provider] ASC;


-- 5.7
SELECT 
    Id,
    Email,
    LastLoginAtUtc
FROM [identity].Users
ORDER BY 
    CASE WHEN LastLoginAtUtc IS NULL THEN 1
	ELSE 0 
	END,
    LastLoginAtUtc DESC;
GO

-- 5.8
SELECT 
    Id,
    InvoiceId,
    Amount,
    CurrencyCode,
    PaidAtUtc
FROM finance.Payments
WHERE PaidAtUtc >= '2026-10-01' 
  AND PaidAtUtc < '2026-11-01';
GO

-- 5.9
SELECT 
    Id,
    Amount,
    PaidAtUtc,
    PaidAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Egypt Standard Time' AS PaidAtCairo
FROM finance.Payments
WHERE CAST(PaidAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Egypt Standard Time' AS TIME) >= '00:00:00'
  AND CAST(PaidAtUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Egypt Standard Time' AS TIME) < '05:00:00';
GO

-- 5.10
SELECT 
    Id,
    SectionId,
    SessionDate,
    Topic
FROM attendance.AttendanceSessions
WHERE DATENAME(WEEKDAY, SessionDate) = 'Friday';
GO

-- 5.11
SELECT 
    Id,
    FirstName,
    LastName,
    PhoneNumber
FROM [identity].Users
WHERE PhoneNumber LIKE '+201[0125]%' 
   OR PhoneNumber LIKE '01[0125]%';
GO

-- 5.12
SELECT 
    Id,
    PhoneNumber,
    LEFT(PhoneNumber, 3) +
	REPLICATE('*', LEN(PhoneNumber) - 5) +
	RIGHT(PhoneNumber, 2) AS MaskedPhoneNumber
FROM [identity].Users
WHERE PhoneNumber IS NOT NULL;
GO

-- 5.13
SELECT 
    Id,
    InvoiceNumber,
    TRY_CAST(REPLACE(RIGHT(InvoiceNumber, CHARINDEX('-', REVERSE(InvoiceNumber)) - 1), 'NB', '') AS BIGINT) AS RunningNumber
FROM finance.Invoices
ORDER BY RunningNumber ASC;
GO

-- 5.14
SELECT 
    Id,
    Title,
    CASE 
        WHEN EstimatedMinutes IS NULL THEN 'Not set'
        ELSE CAST(EstimatedMinutes / 60 AS VARCHAR(10)) +
		' h ' +
		CAST(EstimatedMinutes % 60 AS VARCHAR(10)) +
		' min'
    END AS LessonDuration
FROM content.Lessons;
GO

-- 5.15
SELECT 
    Id,
    Title,
    Body
FROM communication.Announcements
WHERE Title LIKE '%[%]%' 
   OR Body LIKE '%[%]%';
GO

-- 5.16
SELECT TOP (5) WITH TIES
    Id,
    InvoiceNumber,
    TotalAmount
FROM finance.Invoices
ORDER BY TotalAmount DESC;
GO

-- 5.17
SELECT TOP (10) PERCENT
    Id,
    InvoiceId,
    Amount,
    PaidAtUtc
FROM finance.Payments
ORDER BY Amount DESC;
GO

-- 5.18
SELECT 
    Id,
    CourseId,
    SectionCode,
    Location
FROM delivery.Sections
WHERE Location <> 'Hall A' 
   OR Location IS NULL;
GO

-- 5.19
SELECT 
    Id,
    InvoiceNumber,
    TotalAmount,
    PaidAmount,
    (TotalAmount - PaidAmount) AS RemainingAmount,
    CASE WHEN PaidAmount > 0 THEN 'Partially Paid' 
	ELSE 'Not Paid' 
	END AS PaymentState,
    CASE WHEN DueAtUtc < SYSUTCDATETIME() 
	THEN 'Overdue' 
	ELSE 'Not Overdue' 
	END AS OverdueStatus,
    CAST(ROUND((PaidAmount * 100.0) / NULLIF(TotalAmount, 0), 1) AS DECIMAL(5,1)) AS PercentagePaid
FROM finance.Invoices
WHERE PaidAmount < TotalAmount
ORDER BY RemainingAmount DESC;
GO

-- 5.20
SELECT 
    Id,
    Email,
    CreatedAtUtc
FROM [identity].Users
ORDER BY CreatedAtUtc DESC, Id DESC
OFFSET 40 ROWS
FETCH NEXT 20 ROWS ONLY;
GO

-- 5.21
DECLARE @LastSeenId BIGINT = 50000;

SELECT TOP (50) 
    Id,
    OccurredAtUtc,
    ActionCode,
    EntityName
FROM operations.AuditLogs
WHERE Id > @LastSeenId
ORDER BY Id ASC;
GO

-- 5.22
SELECT TOP (10) 
    Id,
    InvoiceId,
    Amount,
    PaidAtUtc
FROM finance.Payments
ORDER BY PaidAtUtc DESC, Id DESC;
GO

-- 5.23
SELECT DISTINCT TOP (10)
    UPPER(TRIM(Title)) AS CleanTitle,
    LEN(TRIM(Title)) AS TitleLength,
    CASE 
        WHEN EstimatedMinutes IS NULL THEN 'Not set'
        WHEN EstimatedMinutes <= 15 THEN 'quick'
        WHEN EstimatedMinutes <= 45 THEN 'standard'
        ELSE 'long'
    END AS DurationCategory
FROM content.Lessons
WHERE IsPublished = 1 
  AND LEN(TRIM(Title)) > 40
ORDER BY TitleLength DESC;
GO

-- 5.24
SELECT TOP (12)
    FORMAT(DueAtUtc, 'yyyy-MM') AS DueMonth,
    CurrencyCode,
    CASE WHEN PaidAmount > 0 
	THEN 'Partially Paid' 
	ELSE 'Not Paid' 
	END AS PaymentState,
    COUNT(*) AS InvoiceCount,
    SUM(TotalAmount - PaidAmount) AS TotalRemainingAmount
FROM finance.Invoices
WHERE DueAtUtc < SYSUTCDATETIME() 
  AND PaidAmount < TotalAmount
GROUP BY 
    FORMAT(DueAtUtc, 'yyyy-MM'),
    CurrencyCode,
    CASE WHEN PaidAmount > 0 THEN 'Partially Paid' ELSE 'Not Paid' END
ORDER BY DueMonth DESC;
GO


--6
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT TOP (15)
    i.InvoiceNumber,
    sp.StudentNumber,
    i.TotalAmount - i.PaidAmount AS Remaining,
    CASE WHEN i.DueAtUtc < DATEADD(DAY, -60, SYSUTCDATETIME()) THEN 'Urgent' ELSE 'Normal' END AS Urgency
FROM finance.Invoices AS i
INNER JOIN [identity].StudentProfiles AS sp ON sp.Id = i.StudentId
WHERE i.PaidAmount < i.TotalAmount
  AND i.DueAtUtc < SYSUTCDATETIME()
ORDER BY Remaining DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


-- 7.1
SELECT Id, Email 
	FROM [identity].Users 
	WHERE CreatedAtUtc >= '2026-03-01' 
	AND 
	CreatedAtUtc < '2026-04-01';

-- 7.2
SELECT Id, InvoiceId, Amount 
	FROM finance.Payments 
	WHERE PaidAtUtc >= DATEADD(DAY, -30, SYSUTCDATETIME());

-- 7.3
SELECT Id, FirstName, LastName 
	FROM [identity].Users 
	WHERE LastName LIKE N'Abd%';

-- 7.4
SELECT * 
	FROM operations.AuditLogs 
	WHERE Id = 50000;

-- 7.5
SELECT Id, TotalAmount, PaidAmount 
	FROM finance.Invoices 
	WHERE InvoiceNumber = 'LAB-INV-2026-000001';

-- 7.6
DECLARE @Email VARCHAR(320) = 'it.admin@northbridge.edu';
	SELECT Id, FirstName, LastName 
		FROM [identity].Users 
		WHERE Email = @Email;

-- 7.7
DECLARE @LastName NVARCHAR(100) = N'Hassan';
	SELECT Id, FirstName, Email 
		FROM [identity].Users 
		WHERE (@LastName IS NULL OR LastName = @LastName)
		OPTION (RECOMPILE);

-- 7.8

SELECT Id, Amount 
	FROM finance.Payments 
	WHERE PaidAtUtc >= '2026-10-15' 
	AND 
	PaidAtUtc < '2026-10-16';


--8

SELECT TOP (100000)
    Id AS OrderId,
    InvoiceNumber,
    TotalAmount,
    CurrencyCode,
    DueAtUtc
INTO dbo.LargeOrders
FROM finance.Invoices;
GO

--Tempdb Spill
DECLARE @Cutofff DATETIME2 = '2020-01-01';

SELECT *
	FROM dbo.LargeOrders
		WHERE DueAtUtc > @Cutofff
		ORDER BY TotalAmount DESC;


DECLARE @Cutoff DATETIME2 = '2020-01-01';

SELECT *
	FROM dbo.LargeOrders
	WHERE DueAtUtc > @Cutoff
	ORDER BY TotalAmount DESC
	OPTION (RECOMPILE);

--9

SELECT DISTINCT CurrencyCode 
FROM dbo.LargeOrders;

SELECT DISTINCT Id 
FROM finance.Invoices;


-- 11.1:
UPDATE academic.Courses
	SET PassingScore = 65
	WHERE DepartmentId = 
	(SELECT Id FROM academic.Departments WHERE Code = 'DSAI');
GO

UPDATE delivery.Enrollments
SET FinalGrade = CASE 
    WHEN FinalScore >= 90 THEN 'A'
    WHEN FinalScore >= 80 THEN 'B'
    WHEN FinalScore >= 70 THEN 'C'
    WHEN FinalScore >= 60 THEN 'D'
    ELSE 'F'
END
WHERE CompletedAtUtc IS NOT NULL 
  AND FinalScore IS NOT NULL;
GO

-- 11.3
DELETE FROM [identity].Roles
	WHERE Code IN ('TEACHING_ASSISTANT', 'TA') 
	OR Name = 'Teaching Assistants';
GO

-- 11.4

DROP TABLE IF EXISTS finance.PaymentStaging;
GO

CREATE TABLE finance.PaymentStaging
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNumber VARCHAR(30),
    Amount DECIMAL(12,2),
    PaidAtUtc DATETIME2
);
GO

INSERT INTO finance.PaymentStaging 
	(InvoiceNumber, Amount, PaidAtUtc)
	VALUES 
		('INV-STG-001', 1500.00, SYSUTCDATETIME()),
		('INV-STG-002', 2500.00, SYSUTCDATETIME()),
		('INV-STG-003', 3500.00, SYSUTCDATETIME());
GO

TRUNCATE TABLE finance.PaymentStaging;
GO

-- 11.5
DROP TABLE IF EXISTS dbo.LargeOrders;
DROP TABLE IF EXISTS finance.PaymentStaging;
GO


-- 12.1
GO

CREATE TABLE academic.CoursePassMarkAudit
(
    CourseId INT,
    OldPassingScore DECIMAL(5,2),
    NewPassingScore DECIMAL(5,2),
    ChangedAtUtc DATETIME2,
    ChangedBy NVARCHAR(100)
);
GO

UPDATE academic.Courses
	SET PassingScore = 70
	OUTPUT 
		deleted.Id,
		deleted.PassingScore AS OldPassingScore,
		inserted.PassingScore AS NewPassingScore,
		SYSUTCDATETIME(),
		SUSER_SNAME()
	INTO academic.CoursePassMarkAudit 
	(CourseId, OldPassingScore, NewPassingScore, ChangedAtUtc, ChangedBy)
	WHERE DepartmentId = 
	(SELECT Id FROM academic.Departments WHERE Code = 'DSAI');
GO

-- 12.2
GO

CREATE TABLE communication.AnnouncementArchive
(
    Id BIGINT,
    Title NVARCHAR(200),
    Body NVARCHAR(MAX),
    ExpiresAtUtc DATETIME2,
    ArchivedAtUtc DATETIME2
);
GO

DELETE FROM communication.Announcements
OUTPUT 
    deleted.Id,
    deleted.Title,
    deleted.Body,
    deleted.ExpiresAtUtc,
    SYSUTCDATETIME()
INTO communication.AnnouncementArchive (Id, Title, Body, ExpiresAtUtc, ArchivedAtUtc)
WHERE ExpiresAtUtc < DATEADD(MONTH, -6, SYSUTCDATETIME());
GO


GO

CREATE TABLE dbo.WebsiteCourseCatalog
(
    CourseId INT PRIMARY KEY,
    Code VARCHAR(30),
    Title NVARCHAR(200),
    CreditHours DECIMAL(5,2),
    IsActive BIT
);
GO

MERGE dbo.WebsiteCourseCatalog AS target
	USING academic.Courses AS source
	ON (target.CourseId = source.Id)
	WHEN MATCHED AND (
	    target.Code <> source.Code OR 
	    target.Title <> source.Title OR 
	    target.CreditHours <> source.CreditHours OR
		target.IsActive <> source.IsActive
) THEN
    UPDATE SET 
        target.Code = source.Code,
        target.Title = source.Title,
        target.CreditHours = source.CreditHours,
        target.IsActive = source.IsActive
WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
    INSERT (CourseId, Code, Title, CreditHours, IsActive)
    VALUES (source.Id, source.Code, source.Title, source.CreditHours, source.IsActive)
WHEN NOT MATCHED BY SOURCE THEN
    UPDATE SET target.IsActive = 0
OUTPUT $action, inserted.CourseId, inserted.Title;
GO
--«·’—«ÕÂ „‘ ›«Â„ ﬂÊœ «·„Ì—Ã œÂ