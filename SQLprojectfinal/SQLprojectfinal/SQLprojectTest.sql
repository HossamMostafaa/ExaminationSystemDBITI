select * from students;
select * from course;
select * from questions;
select * from exams;
select * from examquestions;
select * from studentanswers;
select * from results;

exec add_student 'ahmed ali', 1, 1;

insert into course(crs_id, crs_name) values (2, 'database fundamentals');

exec add_question 1, n'ما هو sql؟', 'structured query language';

exec create_exam 1, '2026-03-26';
exec generate_random_exam 1, 1;

exec submit_or_update_answer 1, 1, 1, 'structured query language';

exec correct_exam 1,1;
exec calculate_result 1,1;
exec store_exam_results 1;
select * from results;

select dbo.get_student_score(1,1) as studentscore;
select dbo.get_exam_total(1) as examtotal;

use examinationsystemdb;
go

exec add_student 'ahmed ali', 1, 1;
exec add_student 'sara mohamed', 1, 1;
exec add_student 'omar taha', 1, 1;

insert into course(crs_id, crs_name) values
(1, 'database fundamentals'),
(2, 'web development');

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

go
create procedure exam_full_report
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
        case 
            when a.studentanswer = q.correctanswer then 1
            else 0
        end as iscorrect,
        eq.degree as maxscore,
        case 
            when a.studentanswer = q.correctanswer then eq.degree
            else 0
        end as scoreearned
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

exec exam_full_report 1;