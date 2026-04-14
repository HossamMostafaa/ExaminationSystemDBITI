create procedure add_student
    @name nvarchar(100),
    @track_id int,
    @intake_id int
as
begin
    insert into students (name, track_id, intake_id)
    values (@name, @track_id, @intake_id)
end
go

create procedure add_question
    @course_id int,
    @question_text nvarchar(max),
    @correctanswer nvarchar(100)
as
begin
    insert into questions (course_id, question_text, correctanswer)
    values (@course_id, @question_text, @correctanswer)
end
go

create procedure create_exam
    @course_id int,
    @exam_date date
as
begin
    insert into exams (course_id, exam_date)
    values (@course_id, @exam_date)
end
go

create procedure generate_random_exam
    @exam_id int,
    @num_questions int
as
begin
    insert into examquestions (exam_id, question_id)
    select @exam_id, question_id
    from questions
    order by newid()
    offset 0 rows fetch next @num_questions rows only
end
go

create procedure submit_answer
    @student_id int,
    @exam_id int,
    @question_id int,
    @studentanswer nvarchar(100)
as
begin
    insert into studentanswers (std_id, exam_id, question_id, studentanswer)
    values (@student_id, @exam_id, @question_id, @studentanswer)
end
go

create function get_student_score(@exam_id int, @student_id int)
returns decimal(5,2)
as
begin
    declare @score decimal(5,2)

    select @score = sum(
        case when q.correctanswer = a.studentanswer then eq.degree else 0 end
    )
    from question_pool q
    join exam_questions eq on q.question_id = eq.question_id
    join student_answers a on a.question_id = q.question_id and a.exam_id = eq.exam_id
    where eq.exam_id = @exam_id and a.std_id = @student_id

    return @score
end
go

create function get_exam_total(@exam_id int)
returns decimal(5,2)
as
begin
    declare @total decimal(5,2)

    select @total = sum(degree)
    from exam_questions
    where exam_id = @exam_id

    return @total
end
go

create table students (
    student_id int primary key identity(1,1),
    name nvarchar(100) not null,
    track_id int not null,
    intake_id int not null
)

create table questions (
    question_id int primary key identity(1,1),
    course_id int not null,
    question_text nvarchar(max) not null,
    correctanswer nvarchar(100) not null
)

create table exams (
    exam_id int primary key identity(1,1),
    course_id int not null,
    exam_date date not null
)

create table studentanswers (
    std_id int not null,
    exam_id int not null,
    question_id int not null,
    studentanswer nvarchar(100),
    primary key (std_id, exam_id, question_id)
)

create table examquestions (
    exam_id int not null,
    question_id int not null,
    primary key (exam_id, question_id)
)

create table results (
    std_id int not null,
    exam_id int not null,
    totalscore decimal(5,2) not null,
    primary key (std_id, exam_id)
)

go

create procedure store_exam_results
    @exam_id int
as
begin
    delete from results
    where exam_id = @exam_id

    insert into results (std_id, exam_id, totalscore)
    select 
        a.std_id,
        a.exam_id,
        sum(case 
                when q.correctanswer = a.studentanswer then eq.degree 
                else 0 
            end) as totalscore
    from student_answers a
    join exam_questions eq 
        on a.question_id = eq.question_id
        and a.exam_id = eq.exam_id
    join question_pool q 
        on q.question_id = a.question_id
    where a.exam_id = @exam_id
    group by a.std_id, a.exam_id
end
go

create procedure submit_or_update_answer
    @student_id int,
    @exam_id int,
    @question_id int,
    @studentanswer nvarchar(100)
as
begin
    if exists (
        select 1
        from studentanswers
        where std_id = @student_id
          and exam_id = @exam_id
          and question_id = @question_id
    )
    begin
        update studentanswers
        set studentanswer = @studentanswer
        where std_id = @student_id
          and exam_id = @exam_id
          and question_id = @question_id
    end
    else
    begin
        insert into studentanswers (std_id, exam_id, question_id, studentanswer)
        values (@student_id, @exam_id, @question_id, @studentanswer)
    end
end
go

exec add_student 'ahmed ali', 1, 1
exec add_student 'sara mohamed', 1, 1
exec add_student 'omar taha', 1, 1

insert into course(crs_id, crs_name)
values 
(1, 'database fundamentals'),
(2, 'web development')

exec add_question 1, n'ما هو sql؟', 'structured query language'
exec add_question 1, n'ما هو primary key؟', 'unique identifier'
exec add_question 1, n'ما هو foreign key؟', 'reference to primary key'

exec create_exam 1, '2026-03-26'
exec generate_random_exam 1, 3

exec submit_answer 1, 1, 1, 'structured query language'
exec submit_answer 1, 1, 2, 'unique identifier'
exec submit_answer 1, 1, 3, 'reference to primary key'

exec submit_answer 2, 1, 1, 'structured query language'
exec submit_answer 2, 1, 2, 'wrong answer'
exec submit_answer 2, 1, 3, 'reference to primary key'

exec store_exam_results 1

select * from results where exam_id = 1
select * from students