use examinationsystemdb;
go

create or alter procedure add_student
    @name nvarchar(100),
    @track_id int,
    @intake_id int
as
begin
    insert into students (name, track_id, intake_id)
    values (@name, @track_id, @intake_id);
end
go

create or alter procedure add_question
    @course_id int,
    @question_text nvarchar(max),
    @correctanswer nvarchar(100)
as
begin
    insert into questions (course_id, question_text, correctanswer)
    values (@course_id, @question_text, @correctanswer);
end
go

create or alter procedure create_exam
    @course_id int,
    @exam_date date
as
begin
    insert into exams (course_id, exam_date)
    values (@course_id, @exam_date);
end
go

create or alter procedure generate_random_exam
    @exam_id int,
    @numquestions int
as
begin
    insert into examquestions (exam_id, question_id)
    select top (@numquestions) @exam_id, q.question_id
    from questions q
    where q.question_id not in (
        select question_id from examquestions where exam_id = @exam_id
    )
    order by newid();
end
go

create or alter procedure submit_or_update_answer
    @student_id int,
    @exam_id int,
    @question_id int,
    @studentanswer nvarchar(100)
as
begin
    if exists (
        select 1 from studentanswers
        where std_id = @student_id
          and exam_id = @exam_id
          and question_id = @question_id
    )
    begin
        update studentanswers
        set studentanswer = @studentanswer
        where std_id = @student_id
          and exam_id = @exam_id
          and question_id = @question_id;
    end
    else
    begin
        insert into studentanswers (std_id, exam_id, question_id, studentanswer)
        values (@student_id, @exam_id, @question_id, @studentanswer);
    end
end
go

create or alter procedure correct_exam
    @exam_id int,
    @student_id int
as
begin
    select q.question_id,
           q.correctanswer,
           a.studentanswer as answer,
           case when q.correctanswer = a.studentanswer then 1 else 0 end as iscorrect
    from questions q
    join examquestions eq
        on q.question_id = eq.question_id
    join studentanswers a
        on a.question_id = q.question_id
    where eq.exam_id = @exam_id
      and a.std_id = @student_id;
end
go

create or alter procedure calculate_result
    @exam_id int,
    @student_id int
as
begin
    select sum(
        case when q.correctanswer = a.studentanswer then 1 else 0 end
    ) as totalscore
    from questions q
    join examquestions eq
        on q.question_id = eq.question_id
    join studentanswers a
        on a.question_id = q.question_id
    where eq.exam_id = @exam_id
      and a.std_id = @student_id;
end
go

create or alter procedure store_exam_results
    @exam_id int
as
begin
    delete from results where exam_id = @exam_id;

    insert into results (std_id, exam_id, totalscore)
    select a.std_id,
           a.exam_id,
           sum(case when q.correctanswer = a.studentanswer then 1 else 0 end) as totalscore
    from studentanswers a
    join examquestions eq
        on a.exam_id = eq.exam_id
       and a.question_id = eq.question_id
    join questions q
        on q.question_id = a.question_id
    where a.exam_id = @exam_id
    group by a.std_id, a.exam_id;
end
go

create or alter procedure exam_full_report
    @exam_id int
as
begin
    select 
        s.student_id,
        s.name as studentname,
        q.question_id,
        q.question_text,
        a.studentanswer,
        q.correctanswer,
        case when a.studentanswer = q.correctanswer then 1 else 0 end as iscorrect,
        1 as maxscore,
        case when a.studentanswer = q.correctanswer then 1 else 0 end as scoreearned
    from students s
    join studentanswers a
        on s.student_id = a.std_id
    join examquestions eq
        on a.exam_id = eq.exam_id
       and a.question_id = eq.question_id
    join questions q
        on q.question_id = a.question_id
    where a.exam_id = @exam_id
    order by s.student_id, q.question_id;
end
go

create or alter function get_student_score
(
    @student_id int,
    @exam_id int
)
returns int
as
begin
    declare @score int;

    select @score = sum(case when q.correctanswer = a.studentanswer then 1 else 0 end)
    from studentanswers a
    join questions q
        on q.question_id = a.question_id
    join examquestions eq
        on a.exam_id = eq.exam_id
       and a.question_id = eq.question_id
    where a.std_id = @student_id
      and a.exam_id = @exam_id;

    return isnull(@score,0);
end
go

create or alter function get_exam_total
(
    @exam_id int
)
returns int
as
begin
    declare @total int;

    select @total = count(*)
    from examquestions
    where exam_id = @exam_id;

    return isnull(@total,0);
end
go

exec add_student 'ahmed ali', 1, 1;
exec add_student 'sara mohamed', 1, 1;
exec add_student 'omar taha', 1, 1;

insert into course(crs_name) values ('database fundamentals');
insert into course(crs_name) values ('web development');

exec add_question 1, n'ما هو sql؟', 'structured query language';
exec add_question 1, n'ما هو primary key؟', 'unique identifier';
exec add_question 1, n'ما هو foreign key؟', 'reference to primary key';

exec add_question 2, n'ما هو html؟', 'hypertext markup language';
exec add_question 2, n'ما هو css؟', 'cascading style sheets';
exec add_question 2, n'ما هو javascript؟', 'programming language';

exec create_exam 1, '2026-03-26';
exec create_exam 2, '2026-03-27';

exec generate_random_exam 1, 3;
exec generate_random_exam 2, 3;

exec submit_or_update_answer 1, 1, 1, 'structured query language';
exec submit_or_update_answer 1, 1, 2, 'unique identifier';
exec submit_or_update_answer 1, 1, 3, 'reference to primary key';

exec submit_or_update_answer 2, 1, 1, 'structured query language';
exec submit_or_update_answer 2, 1, 2, 'wrong answer';
exec submit_or_update_answer 2, 1, 3, 'reference to primary key';

exec submit_or_update_answer 3, 1, 1, 'wrong answer';
exec submit_or_update_answer 3, 1, 2, 'unique identifier';
exec submit_or_update_answer 3, 1, 3, 'wrong answer';

exec submit_or_update_answer 1, 2, 4, 'hypertext markup language';
exec submit_or_update_answer 1, 2, 5, 'cascading style sheets';
exec submit_or_update_answer 1, 2, 6, 'programming language';

exec submit_or_update_answer 2, 2, 4, 'wrong answer';
exec submit_or_update_answer 2, 2, 5, 'cascading style sheets';
exec submit_or_update_answer 2, 2, 6, 'wrong answer';

exec submit_or_update_answer 3, 2, 4, 'hypertext markup language';
exec submit_or_update_answer 3, 2, 5, 'wrong answer';
exec submit_or_update_answer 3, 2, 6, 'programming language';

exec correct_exam 1, 1;
exec correct_exam 2, 1;

exec correct_exam 1, 2;
exec correct_exam 2, 2;

exec store_exam_results 1;
exec store_exam_results 2;

select * from results;

select dbo.get_student_score(1,1) as student1_exam1_score;
select dbo.get_student_score(2,1) as student2_exam1_score;
select dbo.get_exam_total(1) as exam1_totalscore;

exec exam_full_report 1;
exec exam_full_report 2;