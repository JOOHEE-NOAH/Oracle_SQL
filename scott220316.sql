-------------------------------------------------------------------
-------    Trigger : 주의! 무결성용으로 사용하지 말것/트리거에서는 선언을 is가 아닌 declare로 함
-------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trigger_test
BEFORE
UPDATE ON dept
FOR EACH ROW -- old, new 사용하기 위해
BEGIN
    DBMS_OUTPUT.ENABLE;
    DBMS_OUTPUT.PUT_LINE('변경 전 컬럼 값 : ' || :old.loc);
    DBMS_OUTPUT.PUT_LINE('변경 후 컬럼 값 : ' || :new.loc);
    
END;

UPDATE dept
SET loc = '합정2'
WHERE deptno = 41;

--실행결과 보기: 상단 메뉴-> 보기 -> DBMS 출력 -> DBMS 출력 창에서 + 에서 scott선택하고 update 실행.


----------------------------------------------------------
--문제 ) emp Table의 급여가 변화시
--       화면에 출력하는 Trigger 작성( emp_sal_change)
--       emp Table 수정전
--      조건 : 입력시는 empno가 0보다 커야함

--출력결과 예시
--     이전급여  : 10000
--     신  급여  : 15000
 --    급여 차액 :  5000
----------------------------------------------------------
CREATE OR REPLACE TRIGGER emp_sal_change
BEFORE DELETE OR INSERT OR UPDATE ON emp
FOR EACH ROW
    WHEN (new.empno > 0 )
    DECLARE
        sal_diff number;
BEGIN
    sal_diff    := :new.sal - :old.sal;
    dbms_output.put_line('사번 : ' || :old.empno);
    dbms_output.put_line('이름 : ' || :old.ename);
    dbms_output.put_line('이전 급여 : ' || :old.sal);
    dbms_output.put_line('신   급여 : ' || :new.sal);
    dbms_output.put_line('급여 차액 : ' || sal_diff);
END;
    
UPDATE emp
SET    sal = 2000
WHERE  empno = 1002
;

-----------------------------------------------------------
--  EMP 테이블에 INSERT,UPDATE,DELETE문장이 하루에 몇 건의 ROW가 발생되는지 조사
--  조사 내용은 EMP_ROW_AUDIT에 
--  ID ,사용자 이름, 작업 구분,작업 일자시간을 저장하는 
--  트리거를 작성
-----------------------------------------------------------
-- 1. SEQUENCE
-- DROP SEQUENCE emp_row_seq;
CREATE SEQUENCE emp_row_seq;
--2. Audit Table
--DROP TABLE emp_row_audit;
CREATE TABLE emp_row_audit(
    e_id        NUMBER(6)       CONSTRAINT emp_row_pk PRIMARY KEY,
    e_name      VARCHAR2(30),
    e_gubun     VARCHAR2(10),
    e_date      DATE
);
-- 3. Trigger
CREATE OR REPLACE TRIGGER emp_row_aud
AFTER DELETE OR INSERT OR UPDATE ON emp
FOR EACH ROW
    BEGIN
        IF INSERTING THEN
            INSERT INTO emp_row_audit
                VALUES(emp_row_seq.NEXTVAL, :new.ename, 'inserting', SYSDATE);
        ELSIF UPDATING THEN
            INSERT INTO emp_row_audit
                VALUES(emp_row_seq.NEXTVAL, :old.ename, 'updating', SYSDATE);
        ELSIF DELETING THEN
            INSERT INTO emp_row_audit
                VALUES(emp_row_seq.NEXTVAL, :old.ename, 'deleting', SYSDATE);
        END IF;
END;

--4. 수정 시 emp_row_aud 결과 학인
UPDATE emp
SET    ename = 'trigger'
WHERE  empno = 1002;
--emp의 데이터 변경시 (insert,update,delete)시 변경내역을 emp_row_audit에 저장됨.

INSERT INTO emp(empno, ename, sal, deptno)
        VALUES(3000,'강희준', 3500, 40);
INSERT INTO emp(empno, ename, sal, deptno)
        VALUES(3100,'김주희', 3400, 40);
DELETE emp WHERE empno = 1004;


---------------------------------------------------------------------------------------
-----    Package -> 인터페이스 같은거라고 생각해라
--header와 body로 나눠짐
----------------------------------------------------------------------------------------

-- 1.Header -->  역할 : 선언 (Interface 역할)
--                여러 PROCEDURE 선언 가능
CREATE OR REPLACE PACKAGE emp_info AS  -->자바: 클라스명같은 것
    PROCEDURE all_emp_info; -- 모든 사원의 사원 정보
    PROCEDURE all_sal_info; -- 모든 사원의 급여 정보
    PROCEDURE dept_emp_info (p_deptno IN NUMBER); --특정 부서의 사원 정보
    PROCEDURE dept_sal_info (p_deptno IN NUMBER); --특정 부서의 급여 정보
END  emp_info;

--2.body 역할 : 실제 구현
CREATE OR REPLACE PACKAGE BODY emp_info AS
    -----------------------------------------------------------------
    -- 모든 사원의 사원 정보(사번, 이름, 입사일)
    -- 1. CURSOR  : emp_cursor 
    -- 2. FOR  IN
    -- 3. DBMS  -> 각각 줄 바꾸어 사번,이름,입사일 
    -----------------------------------------------------------------
    PROCEDURE all_emp_info
    IS
    CURSOR emp_cursor IS
    SELECT empno, ename, to_char(hiredate, 'yyyy/mm/dd') hiredate
    FROM emp
    ORDER BY hiredate;
        
    BEGIN
        DBMS_OUTPUT.ENABLE;    
        FOR emp IN emp_cursor LOOP
            DBMS_OUTPUT.PUT_LINE('사번 : '|| emp.empno);
            DBMS_OUTPUT.PUT_LINE('이름 : '|| emp.ename);
            DBMS_OUTPUT.PUT_LINE('입사일 : '|| emp.hiredate);
        END LOOP;   
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(SQLERRM||'에러 발생');
    END all_emp_info; -->프로시저 엔드
   
    -----------------------------------------------------------------
    -- 모든 사원의 급여 정보
    -- 1. CURSOR  : emp_cursor 
    -- 2. FOR  IN
    -- 3. DBMS  -> 각각 줄 바꾸어 전체급여평균 , 최대급여금액 , 최소급여금액
   -----------------------------------------------------------------
    PROCEDURE all_sal_info
    IS
    CURSOR emp_cursor IS
    SELECT ROUND(AVG(sal),3) avg, MAX(sal) max, MIN(sal) min
    FROM emp;
  --GROUP BY deptno; --> 부서별로 뽑고 싶을 경우
    BEGIN
        DBMS_OUTPUT.ENABLE;    
        FOR emp IN emp_cursor LOOP
            DBMS_OUTPUT.PUT_LINE('전체급여평균 : '|| emp.avg);
            DBMS_OUTPUT.PUT_LINE('최대급여금액 : '|| emp.max);
            DBMS_OUTPUT.PUT_LINE('최소급여금액 : '|| emp.min);
        END LOOP;   
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(SQLERRM||'에러 발생');
    
    END all_sal_info;
    
    -----------------------------------------------------------------
    --특정 부서의 해당하는 사원 정보
    -- 1. CURSOR  : emp_cursor 
    -- 2. FOR  IN
    -- 3. DBMS  -> 특정 부서의 해당하는 사원 사번,이름, 입사일 
   -----------------------------------------------------------------
    PROCEDURE dept_emp_info 
    (p_deptno IN NUMBER)
    IS
    CURSOR emp_cursor IS
    SELECT empno, ename, to_char(hiredate, 'yyyy/mm/dd') hiredate
    FROM emp
    WHERE deptno=p_deptno
    ORDER BY hiredate;
  
    BEGIN
        DBMS_OUTPUT.ENABLE;    
        FOR emp IN emp_cursor LOOP
            DBMS_OUTPUT.PUT_LINE('사번 : '|| emp.empno);
            DBMS_OUTPUT.PUT_LINE('이름 : '|| emp.ename);
            DBMS_OUTPUT.PUT_LINE('입사일 : '|| emp.hiredate);
        END LOOP;   
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(SQLERRM||'에러 발생');
    
    END dept_emp_info;
    
    -----------------------------------------------------------------
    --특정 부서의 급여 정보
    -- 1. CURSOR  : emp_cursor 
    -- 2. FOR  IN
    -- 3. DBMS ->특정 부서의 해당하는 특정부서 급여평균 ,특정부서 최대급여금액,특정부서 최소급여금액
   -----------------------------------------------------------------
    PROCEDURE dept_sal_info
    (p_deptno IN NUMBER)
    
    IS
    CURSOR emp_cursor IS
    SELECT dept.dname, ROUND(AVG(emp.sal),3) avg, MAX(emp.sal) max, MIN(emp.sal) min 
    FROM emp , dept
    WHERE emp.deptno=dept.deptno
    AND emp.deptno LIKE p_deptno||'%'
    GROUP BY dept.dname;
    
    BEGIN
        DBMS_OUTPUT.ENABLE;    
        FOR empDept IN emp_cursor LOOP
            DBMS_OUTPUT.PUT_LINE('부  서  명 : '|| empDept.dname);
            DBMS_OUTPUT.PUT_LINE('전체급여평균 : '|| empDept.avg);
            DBMS_OUTPUT.PUT_LINE('최대급여금액 : '|| empDept.max);
            DBMS_OUTPUT.PUT_LINE('최소급여금액 : '|| empDept.min);
            DBMS_OUTPUT.PUT_LINE('-----------------------');
        END LOOP;   
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(SQLERRM||'에러 발생');
    
    END dept_sal_info;
    
END emp_info; -->패키지 엔드


--Output 예시
CREATE OR REPLACE PROCEDURE Emp_Info2
( p_empno IN emp.empno%TYPE, p_ename OUT emp.ename%TYPE, p_sal OUT emp.sal%TYPE )
IS
-- %TYPE 데이터형 변수 선언
v_empno emp.empno%TYPE;
BEGIN
        DBMS_OUTPUT.ENABLE;
        -- %TYPE 데이터형 변수 사용
        SELECT empno, ename, sal
        INTO v_empno, p_ename, p_sal
        FROM emp
        WHERE empno = p_empno ;
        -- 결과값 출력                            ascii코드 10 LF ( Line Feed => 다음 줄로... ), 13CR ( Cariage Return => 제일 처음 칸으로... )
        DBMS_OUTPUT.PUT_LINE('사원번호 : ' || v_empno || CHR(10) || CHR(13) || '줄바뀜');
        DBMS_OUTPUT.PUT_LINE('사원이름 : ' || p_ename );
        DBMS_OUTPUT.PUT_LINE('사원급여 : ' || p_sal );
END;
--




