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