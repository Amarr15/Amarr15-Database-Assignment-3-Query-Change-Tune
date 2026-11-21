-- Task 1 — The Finance Meeting
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
