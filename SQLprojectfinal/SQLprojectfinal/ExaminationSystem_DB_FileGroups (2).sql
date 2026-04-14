GO

EXEC sp_configure 'xp_cmdshell', 0;          RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

-- ================================================================
-- STEP 2: DROP IF EXISTS
-- ================================================================
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'ExaminationSystemDB')
BEGIN
    ALTER DATABASE ExaminationSystemDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ExaminationSystemDB;
END
GO

-- ================================================================
-- STEP 3: CREATE DATABASE WITH FILEGROUPS
--

--  -------------------------------------------------------
-- ================================================================
CREATE DATABASE ExaminationSystemDB
ON PRIMARY
(   NAME='ExamSys_Primary',
FILENAME='C:\SQLData\ExamSys\Primary\ExamSys_Primary.mdf',
    SIZE=10MB,  MAXSIZE=100MB,  
	FILEGROWTH=10MB ),

FILEGROUP FG_LOOKUP
(   NAME='ExamSys_Lookup',   FILENAME='C:\SQLData\ExamSys\Lookup\ExamSys_Lookup.ndf',
    SIZE=5MB,   MAXSIZE=50MB,    FILEGROWTH=5MB  ),

FILEGROUP FG_USERS
(   NAME='ExamSys_Users',    FILENAME='C:\SQLData\ExamSys\Users\ExamSys_Users.ndf',
    SIZE=50MB,  MAXSIZE=500MB,   FILEGROWTH=25MB ),

FILEGROUP FG_COURSES
(   NAME='ExamSys_Courses',  FILENAME='C:\SQLData\ExamSys\Courses\ExamSys_Courses.ndf',
    SIZE=20MB,  MAXSIZE=200MB,   FILEGROWTH=20MB ),

FILEGROUP FG_EXAM
(   NAME='ExamSys_Exam1',    FILENAME='C:\SQLData\ExamSys\Exam\ExamSys_Exam1.ndf',
    SIZE=200MB, MAXSIZE=1000MB,  FILEGROWTH=100MB ),
(   NAME='ExamSys_Exam2',    FILENAME='C:\SQLData\ExamSys\Exam\ExamSys_Exam2.ndf',
    SIZE=200MB, MAXSIZE=1000MB,  FILEGROWTH=100MB ),

FILEGROUP FG_TRANS
(   NAME='ExamSys_Trans1',   FILENAME='C:\SQLData\ExamSys\Trans\ExamSys_Trans1.ndf',
    SIZE=500MB, MAXSIZE=20000MB, FILEGROWTH=500MB ),
(   NAME='ExamSys_Trans2',   FILENAME='C:\SQLData\ExamSys\Trans\ExamSys_Trans2.ndf',
    SIZE=500MB, MAXSIZE=20000MB, FILEGROWTH=500MB ),

FILEGROUP FG_INDEXES
(   NAME='ExamSys_Indexes',  FILENAME='C:\SQLData\ExamSys\Indexes\ExamSys_Indexes.ndf',
    SIZE=100MB, MAXSIZE=5000MB,  FILEGROWTH=200MB )

LOG ON
(   NAME='ExamSys_Log',      FILENAME='C:\SQLLog\ExamSys\ExamSys_Log.ldf',
    SIZE=500MB, MAXSIZE=10000MB, FILEGROWTH=250MB );
GO

USE ExaminationSystemDB;
GO
ALTER DATABASE ExaminationSystemDB SET RECOVERY FULL;
GO

-- ================================================================
-- STEP 4: TABLES
-- ================================================================

-- 1. USER  -> FG_USERS
CREATE TABLE [USER] (
    user_ID    INT          PRIMARY KEY IDENTITY(1,1),
    userName   VARCHAR(100) NOT NULL UNIQUE,
    [Password] VARCHAR(255) NOT NULL,
    role       VARCHAR(20)  NOT NULL CHECK (role IN ('Admin','Instructor','Student'))
) ON FG_USERS;
GO

-- 2. DEPARTMENT  -> FG_LOOKUP
CREATE TABLE Department (
    Dept_Id   INT          PRIMARY KEY IDENTITY(1,1),
    Dept_Name VARCHAR(100) NOT NULL
) ON FG_LOOKUP;
GO

-- 3. BRANCH  -> FG_LOOKUP
CREATE TABLE Branch (
    Branch_ID INT          PRIMARY KEY IDENTITY(1,1),
    Name      VARCHAR(100) NOT NULL,
    Dept_Id   INT          NOT NULL REFERENCES Department(Dept_Id)
) ON FG_LOOKUP;
GO

-- 4. INTAKE  -> FG_LOOKUP
CREATE TABLE Intake (
    Intake_Id  INT          PRIMARY KEY IDENTITY(1,1),
    Name       VARCHAR(100) NOT NULL,
    intakeYear INT          NOT NULL
) ON FG_LOOKUP;
GO

-- 5. TRACK  -> FG_LOOKUP
CREATE TABLE Track (
    Track_Id  INT          PRIMARY KEY IDENTITY(1,1),
    Name      VARCHAR(100) NOT NULL,
    Branch_ID INT          NOT NULL REFERENCES Branch(Branch_ID),
    Intake_Id INT          NOT NULL REFERENCES Intake(Intake_Id)
) ON FG_LOOKUP;
GO

-- 6. INSTRUCTOR  -> FG_USERS
CREATE TABLE Instructor (
    Ins_Id    INT          PRIMARY KEY IDENTITY(1,1),
    Ins_Name  VARCHAR(150) NOT NULL,
    Phone     VARCHAR(20),
    Email     VARCHAR(150) NOT NULL UNIQUE,
    User_ID   INT          NOT NULL UNIQUE REFERENCES [USER](user_ID),
    Branch_ID INT          NOT NULL REFERENCES Branch(Branch_ID)
) ON FG_USERS;
GO

-- 7. STUDENT  -> FG_USERS
CREATE TABLE Student (
    Std_Id   INT          PRIMARY KEY IDENTITY(1,1),
    Std_Name VARCHAR(150) NOT NULL,
    Phone    VARCHAR(20),
    Email    VARCHAR(150) NOT NULL UNIQUE,
    User_ID  INT          NOT NULL UNIQUE REFERENCES [USER](user_ID),
    Track_Id INT          NOT NULL REFERENCES Track(Track_Id)
) ON FG_USERS;
GO

-- 8. COURSE  -> FG_COURSES
CREATE TABLE Course (
    Crs_Id    INT           PRIMARY KEY IDENTITY(1,1),
    Crs_Name  VARCHAR(150)  NOT NULL,
    MinDegree DECIMAL(5,2)  NOT NULL CHECK (MinDegree >= 0),
    MaxDegree DECIMAL(5,2)  NOT NULL CHECK (MaxDegree >  0),
    CONSTRAINT CK_Degree CHECK (MinDegree < MaxDegree)
) ON FG_COURSES;
GO

-- 9. INSTRUCTOR_COURSE  -> FG_COURSES
CREATE TABLE Instructor_Course (
    Ins_Id INT NOT NULL REFERENCES Instructor(Ins_Id),
    Crs_Id INT NOT NULL REFERENCES Course(Crs_Id),
    PRIMARY KEY (Ins_Id, Crs_Id)
) ON FG_COURSES;
GO

-- 10. STUDENT_COURSE  -> FG_COURSES
CREATE TABLE Student_Course (
    Std_Id INT           NOT NULL REFERENCES Student(Std_Id),
    Crs_ID INT           NOT NULL REFERENCES Course(Crs_Id),
    Grade  DECIMAL(5,2)  CHECK (Grade >= 0),
    PRIMARY KEY (Std_Id, Crs_ID)
) ON FG_COURSES;
GO

-- 11. QUESTION_POOL  -> FG_EXAM
CREATE TABLE Question_Pool (
    Question_ID   INT            PRIMARY KEY IDENTITY(1,1),
    Question_Text NVARCHAR(MAX)  NOT NULL,
    QuestionType  VARCHAR(20)    NOT NULL CHECK (QuestionType IN ('MCQ','TrueFalse','Text')),
    McqOptions    NVARCHAR(MAX),
    CorrectAnswer NVARCHAR(MAX)  NOT NULL,
    Crs_Id        INT            NOT NULL REFERENCES Course(Crs_Id),
    CONSTRAINT CK_McqOptions CHECK (
        (QuestionType =  'MCQ' AND McqOptions IS NOT NULL) OR
        (QuestionType <> 'MCQ' AND McqOptions IS NULL)
    )
) ON FG_EXAM TEXTIMAGE_ON FG_EXAM;
GO

-- 12. EXAM  -> FG_EXAM
CREATE TABLE Exam (
    Exam_ID          INT          PRIMARY KEY IDENTITY(1,1),
    ExamType         VARCHAR(20)  NOT NULL CHECK (ExamType IN ('Final','Midterm','Quiz')),
    StartTime        DATETIME     NOT NULL,
    EndTime          DATETIME     NOT NULL,
    TotalTime        AS DATEDIFF(MINUTE, StartTime, EndTime) PERSISTED,
    AllowanceOptions NVARCHAR(MAX),
    Crs_Id           INT          NOT NULL REFERENCES Course(Crs_Id),
    Ins_Id           INT          NOT NULL REFERENCES Instructor(Ins_Id),
    CONSTRAINT CK_ExamTime CHECK (EndTime > StartTime)
) ON FG_EXAM TEXTIMAGE_ON FG_EXAM;
GO

-- 13. EXAM_QUESTIONS  -> FG_EXAM
CREATE TABLE Exam_Questions (
    Exam_Id     INT          NOT NULL REFERENCES Exam(Exam_ID),
    Question_ID INT          NOT NULL REFERENCES Question_Pool(Question_ID),
    Degree      DECIMAL(5,2) NOT NULL CHECK (Degree > 0),
    PRIMARY KEY (Exam_Id, Question_ID)
) ON FG_EXAM;
GO

-- 14. STUDENT_EXAM  -> FG_TRANS
CREATE TABLE Student_Exam (
    Std_Id  INT          NOT NULL REFERENCES Student(Std_Id),
    Exam_Id INT          NOT NULL REFERENCES Exam(Exam_ID),
    Result  DECIMAL(5,2) CHECK (Result >= 0),
    Status  VARCHAR(20)  DEFAULT 'Pending' CHECK (Status IN ('Pending','Pass','Fail')),
    PRIMARY KEY (Std_Id, Exam_Id)
) ON FG_TRANS;
GO

-- 15. STUDENT_ANSWERS  -> FG_TRANS  (largest table)
CREATE TABLE Student_Answers (
    Std_Id        INT           NOT NULL REFERENCES Student(Std_Id),
    Exam_Id       INT           NOT NULL REFERENCES Exam(Exam_ID),
    Question_ID   INT           NOT NULL REFERENCES Question_Pool(Question_ID),
    StudentAnswer NVARCHAR(MAX),
    IsCorrect     BIT,
    Degree_Earned DECIMAL(5,2)  CHECK (Degree_Earned >= 0),
    PRIMARY KEY (Std_Id, Exam_Id, Question_ID),
    CONSTRAINT FK_SA_ExamQuestion
        FOREIGN KEY (Exam_Id, Question_ID)
        REFERENCES Exam_Questions(Exam_Id, Question_ID)
) ON FG_TRANS TEXTIMAGE_ON FG_TRANS;
GO

-- ================================================================
-- STEP 5: NON-CLUSTERED INDEXES  -> ALL ON FG_INDEXES
-- ================================================================
CREATE INDEX IX_User_Role         ON [USER](role)                      ON FG_INDEXES;
CREATE INDEX IX_Student_Track     ON Student(Track_Id)                 ON FG_INDEXES;
CREATE INDEX IX_Student_User      ON Student(User_ID)                  ON FG_INDEXES;
CREATE INDEX IX_Instructor_Branch ON Instructor(Branch_ID)             ON FG_INDEXES;
CREATE INDEX IX_Instructor_User   ON Instructor(User_ID)               ON FG_INDEXES;
CREATE INDEX IX_Track_Branch      ON Track(Branch_ID)                  ON FG_INDEXES;
CREATE INDEX IX_Track_Intake      ON Track(Intake_Id)                  ON FG_INDEXES;
CREATE INDEX IX_Branch_Dept       ON Branch(Dept_Id)                   ON FG_INDEXES;
CREATE INDEX IX_Exam_Course       ON Exam(Crs_Id)                      ON FG_INDEXES;
CREATE INDEX IX_Exam_Instructor   ON Exam(Ins_Id)                      ON FG_INDEXES;
CREATE INDEX IX_Exam_StartTime    ON Exam(StartTime)                   ON FG_INDEXES;
CREATE INDEX IX_Question_Course   ON Question_Pool(Crs_Id)             ON FG_INDEXES;
CREATE INDEX IX_Question_Type     ON Question_Pool(QuestionType)       ON FG_INDEXES;
CREATE INDEX IX_SE_Exam           ON Student_Exam(Exam_Id)             ON FG_INDEXES;
CREATE INDEX IX_SE_Status         ON Student_Exam(Status)              ON FG_INDEXES;
CREATE INDEX IX_SA_ExamStudent    ON Student_Answers(Exam_Id, Std_Id)  ON FG_INDEXES;
CREATE INDEX IX_SA_IsCorrect      ON Student_Answers(IsCorrect)        ON FG_INDEXES;
GO

-- ================================================================
-- STEP 6: VIEWS
-- ================================================================
CREATE VIEW vw_StudentProfile AS
SELECT s.Std_Id, s.Std_Name, s.Email, s.Phone,
       u.userName, u.role,
       t.Name AS Track, b.Name AS Branch, i.Name AS Intake, i.intakeYear
FROM Student s
JOIN [USER] u ON u.user_ID   = s.User_ID
JOIN Track  t ON t.Track_Id  = s.Track_Id
JOIN Branch b ON b.Branch_ID = t.Branch_ID
JOIN Intake i ON i.Intake_Id = t.Intake_Id;
GO

CREATE VIEW vw_ExamResults AS
SELECT s.Std_Id, s.Std_Name,
       e.Exam_ID, e.ExamType, c.Crs_Name,
       se.Result, se.Status, e.StartTime, e.EndTime
FROM Student_Exam se
JOIN Student s ON s.Std_Id  = se.Std_Id
JOIN Exam    e ON e.Exam_ID = se.Exam_Id
JOIN Course  c ON c.Crs_Id  = e.Crs_Id;
GO

CREATE VIEW vw_ExamSummary AS
SELECT e.Exam_ID, e.ExamType, c.Crs_Name, ins.Ins_Name AS InstructorName,
       COUNT(eq.Question_ID) AS TotalQuestions,
       SUM(eq.Degree)        AS TotalMarks,
       e.TotalTime, e.StartTime, e.EndTime
FROM Exam e
JOIN Course           c   ON c.Crs_Id   = e.Crs_Id
JOIN Instructor       ins ON ins.Ins_Id  = e.Ins_Id
LEFT JOIN Exam_Questions eq ON eq.Exam_Id = e.Exam_ID
GROUP BY e.Exam_ID, e.ExamType, c.Crs_Name, ins.Ins_Name,
         e.TotalTime, e.StartTime, e.EndTime;
GO

-- ================================================================
-- STEP 7: VERIFY FILEGROUP ASSIGNMENTS
-- ================================================================
SELECT
    t.name   AS TableName,
    fg.name  AS FileGroup,
    p.rows   AS CurrentRows
FROM sys.tables     t
JOIN sys.indexes    i  ON i.object_id      = t.object_id AND i.index_id <= 1
JOIN sys.filegroups fg ON fg.data_space_id = i.data_space_id
JOIN sys.partitions p  ON p.object_id      = t.object_id AND p.index_id = i.index_id
ORDER BY fg.name, t.name;
GO
