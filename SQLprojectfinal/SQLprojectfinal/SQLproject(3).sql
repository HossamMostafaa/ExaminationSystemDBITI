USE ExaminationSystemDB;
GO

-- ============================================================
-- 1. VIEWS
-- ============================================================

IF OBJECT_ID('student_results_view','V') IS NOT NULL DROP VIEW student_results_view;
GO
CREATE VIEW student_results_view AS
SELECT
    s.std_id,
    s.std_name,
    c.crs_id,
    c.crs_name AS course_name,
    e.exam_id,
    e.starttime,
    se.result
FROM student s
JOIN student_exam se ON s.std_id = se.std_id
JOIN exam e ON se.exam_id = e.exam_id
JOIN course c ON e.crs_id = c.crs_id;
GO

IF OBJECT_ID('exam_details_view','V') IS NOT NULL DROP VIEW exam_details_view;
GO
CREATE VIEW exam_details_view AS
SELECT
    e.exam_id,
    c.crs_name AS course_name,
    e.starttime,
    e.endtime,
    e.totaltime,
    COUNT(eq.question_id) AS numberofquestions,
    ISNULL(SUM(eq.degree),0) AS totaldegree
FROM exam e
JOIN course c ON e.crs_id = c.crs_id
LEFT JOIN exam_questions eq ON e.exam_id = eq.exam_id
GROUP BY e.exam_id,c.crs_name,e.starttime,e.endtime,e.totaltime;
GO

IF OBJECT_ID('course_questions_view','V') IS NOT NULL DROP VIEW course_questions_view;
GO
CREATE VIEW course_questions_view AS
SELECT DISTINCT
    c.crs_id,
    c.crs_name AS course_name,
    q.question_id,
    q.questiontype,
    q.mcqoptions,
    q.correctanswer
FROM course c
JOIN exam e ON c.crs_id=e.crs_id
JOIN exam_questions eq ON e.exam_id=eq.exam_id
JOIN question_pool q ON eq.question_id=q.question_id;
GO

IF OBJECT_ID('students_per_course','V') IS NOT NULL DROP VIEW students_per_course;
GO
CREATE VIEW students_per_course AS
SELECT
    c.crs_id,
    c.crs_name AS course_name,
    s.std_id,
    s.std_name,
    sc.grade
FROM course c
JOIN student_course sc ON c.crs_id=sc.crs_id
JOIN student s ON sc.std_id=s.std_id;
GO

-- ============================================================
-- 2. TRIGGERS
-- ============================================================

IF OBJECT_ID('check_grade_before_insert','TR') IS NOT NULL DROP TRIGGER check_grade_before_insert;
GO
CREATE TRIGGER check_grade_before_insert
ON student_exam
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS(
        SELECT 1
        FROM inserted i
        JOIN exam_questions eq ON i.exam_id=eq.exam_id
        GROUP BY i.exam_id,i.result
        HAVING i.result > SUM(eq.degree)
    )
    BEGIN
        RAISERROR('Result cannot exceed exam total degree',16,1)
        ROLLBACK
        RETURN
    END

    INSERT INTO student_exam(std_id,exam_id,result,status)
    SELECT std_id,exam_id,result,status
    FROM inserted
END
GO

IF OBJECT_ID('update_exam_result','TR') IS NOT NULL DROP TRIGGER update_exam_result;
GO
CREATE TRIGGER update_exam_result
ON student_answers
AFTER INSERT,UPDATE
AS
BEGIN
    UPDATE se
    SET result = ISNULL((
        SELECT SUM(eq.degree)
        FROM student_answers sa
        JOIN exam_questions eq
        ON sa.exam_id=eq.exam_id
        AND sa.question_id=eq.question_id
        WHERE sa.std_id=se.std_id
        AND sa.exam_id=se.exam_id
        AND sa.iscorrect=1
    ),0)
    FROM student_exam se
    WHERE EXISTS(
        SELECT 1
        FROM inserted i
        WHERE i.std_id=se.std_id
        AND i.exam_id=se.exam_id
    )
END
GO

IF OBJECT_ID('prevent_delete_course_with_exams','TR') IS NOT NULL DROP TRIGGER prevent_delete_course_with_exams;
GO
CREATE TRIGGER prevent_delete_course_with_exams
ON course
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS(
        SELECT 1
        FROM deleted d
        JOIN exam e ON d.crs_id=e.crs_id
    )
    BEGIN
        RAISERROR('Cannot delete course with exams',16,1)
        ROLLBACK
        RETURN
    END

    DELETE FROM course
    WHERE crs_id IN (SELECT crs_id FROM deleted)
END
GO

-- ============================================================
-- 3. ROLES
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='admin_role')
    CREATE ROLE admin_role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='training_manager_role')
    CREATE ROLE training_manager_role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='instructor_role')
    CREATE ROLE instructor_role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='student_role')
    CREATE ROLE student_role

GRANT CONTROL ON DATABASE::ExaminationSystemDB TO admin_role

GRANT SELECT,INSERT,UPDATE,DELETE ON course TO training_manager_role
GRANT SELECT,INSERT,UPDATE,DELETE ON student TO training_manager_role
GRANT SELECT,INSERT,UPDATE,DELETE ON instructor TO training_manager_role
GRANT SELECT,INSERT,UPDATE,DELETE ON exam TO training_manager_role
GRANT SELECT,INSERT,UPDATE,DELETE ON student_course TO training_manager_role
GRANT SELECT,INSERT,UPDATE,DELETE ON exam_questions TO training_manager_role

GRANT SELECT ON exam_details_view TO instructor_role
GRANT SELECT ON course_questions_view TO instructor_role
GRANT SELECT,INSERT,UPDATE ON student_answers TO instructor_role

GRANT SELECT ON student_results_view TO student_role
GRANT SELECT ON exam_details_view TO student_role
GRANT SELECT,INSERT ON student_answers TO student_role

-- ============================================================
-- 4. PASSWORD HASHING
-- ============================================================

IF NOT EXISTS(
    SELECT * FROM sys.columns
    WHERE object_id = OBJECT_ID('[user]')
    AND name='salt'
)
ALTER TABLE [user]
ADD salt VARBINARY(16)
GO

IF OBJECT_ID('hashpassword','FN') IS NOT NULL DROP FUNCTION hashpassword
GO
CREATE FUNCTION hashpassword
(
    @password NVARCHAR(255),
    @salt VARBINARY(16)
)
RETURNS VARBINARY(64)
AS
BEGIN
    RETURN HASHBYTES('SHA2_512', CAST(@password AS VARBINARY(MAX)) + @salt)
END
GO

-- ============================================================
-- 4.5 FIX PASSWORD COLUMN
-- ============================================================
ALTER TABLE [user]
ALTER COLUMN [password] NVARCHAR(255) NOT NULL
GO

-- ============================================================
-- 5. USER INSERT TRIGGER
-- ============================================================

DROP TRIGGER IF EXISTS trg_user_insert
GO

CREATE TRIGGER trg_user_insert
ON [user]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @username NVARCHAR(100)
    DECLARE @password NVARCHAR(255)
    DECLARE @role VARCHAR(20)
    DECLARE @salt VARBINARY(16)
    DECLARE @hash VARBINARY(64)
    DECLARE @sql NVARCHAR(MAX)
    DECLARE @rolename NVARCHAR(50)

    DECLARE c CURSOR FOR
    SELECT username,[password],role
    FROM inserted

    OPEN c
    FETCH NEXT FROM c INTO @username,@password,@role

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @salt = CRYPT_GEN_RANDOM(16)
        SET @hash = dbo.hashpassword(@password,@salt)

        UPDATE [user]
        SET password=@hash,
            salt=@salt
        WHERE username=@username

        -- create login
        SET @sql='
        IF NOT EXISTS
        (
            SELECT * FROM sys.server_principals
            WHERE name='''+@username+'''
        )
        CREATE LOGIN ['+@username+']
        WITH PASSWORD='''+@password+'''
        '
        EXEC(@sql)

        -- create user
        SET @sql='
        IF NOT EXISTS
        (
            SELECT * FROM sys.database_principals
            WHERE name='''+@username+'''
        )
        CREATE USER ['+@username+']
        FOR LOGIN ['+@username+']
        '
        EXEC(@sql)

        -- assign role
        SET @rolename =
            CASE @role
                WHEN 'admin' THEN 'admin_role'
                WHEN 'training_manager' THEN 'training_manager_role'
                WHEN 'instructor' THEN 'instructor_role'
                WHEN 'student' THEN 'student_role'
            END

        SET @sql='ALTER ROLE ['+@rolename+'] ADD MEMBER ['+@username+']'
        EXEC(@sql)

        
        SET @sql='ALTER USER ['+@username+'] WITH LOGIN = ['+@username+']'
        EXEC(@sql)

        FETCH NEXT FROM c INTO @username,@password,@role
    END

    CLOSE c
    DEALLOCATE c
END
GO

-- ============================================================
-- 6. LOGIN TEST
-- ============================================================

DELETE FROM [user]

INSERT INTO [user](username,[password],role)
VALUES ('sara','123456','instructor')

EXECUTE AS LOGIN = 'sara'
SELECT * FROM exam_details_view
SELECT * FROM course_questions_view
REVERT
GO

INSERT INTO [user](username,[password],role)
VALUES ('omar','123','student')

SELECT name FROM sys.server_principals 
EXECUTE AS LOGIN = 'omar'
SELECT * FROM exam_details_view
SELECT * FROM student_results_view
REVERT
GO