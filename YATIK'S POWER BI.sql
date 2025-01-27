-- NAME: YATIK SHAKYA
-- PROJECT: COLUMBIA ASIA HOSPITAL PROJECT
-- BATCH: DATA SCIENCE COURSE JULY 2024

-- Question 15: Identifying Top 5 Revenue-Generating Doctors with Fewest Patients

SELECT doctor_name, COUNT(patient_id) AS patient_count, SUM(total_bill) AS total_revenue
FROM doctor_patients_data
GROUP BY doctor_name
ORDER BY patient_count ASC, total_revenue DESC
LIMIT 5;

-- Question 16: Average Waiting Time Decrease Over Three Consecutive Months

WITH monthly_avg_wait AS (
    SELECT department_referral,
        DATE_FORMAT(STR_TO_DATE(date, '%d-%m-%Y %H.%i'), '%Y-%m') AS month,
        AVG(patient_waittime) AS avg_wait_time
    FROM hospital_er
    GROUP BY department_referral, DATE_FORMAT(STR_TO_DATE(date, '%d-%m-%Y %H.%i'), '%Y-%m')
),
wait_comparison AS (
    SELECT department_referral, month, avg_wait_time,
        LEAD(avg_wait_time, 1) OVER (PARTITION BY department_referral ORDER BY month) AS next_month_wait,
        LEAD(avg_wait_time, 2) OVER (PARTITION BY department_referral ORDER BY month) AS third_month_wait
    FROM monthly_avg_wait
)
SELECT DISTINCT department_referral
FROM wait_comparison
WHERE avg_wait_time > next_month_wait 
AND next_month_wait > third_month_wait
AND next_month_wait IS NOT NULL 
AND third_month_wait IS NOT NULL;

-- Question 17: Query Analysis for Doctor Gender Ratios

WITH gender_counts AS (
    SELECT 
        d.doctor_name,
        COUNT(CASE WHEN he.patient_gender = 'M' THEN 1 END) AS male_count,
        COUNT(CASE WHEN he.patient_gender = 'F' THEN 1 END) AS female_count
    FROM doctor_patients_data d
    JOIN hospital_er he ON d.patient_id = he.patient_id
    GROUP BY d.doctor_name
)
SELECT 
    doctor_name,
    male_count,
    female_count,
    CASE 
        WHEN female_count = 0 THEN NULL 
        ELSE ROUND(CAST(male_count AS DECIMAL) / female_count, 2)
    END AS male_female_ratio,
    ROW_NUMBER() OVER (ORDER BY CAST(male_count AS DECIMAL) / NULLIF(female_count, 0) DESC) AS ratio_rank
FROM gender_counts;

-- Question 18: Average satisfaction score of patients for each doctor based on their visits

SELECT d.doctor_name, AVG(CAST(he.patient_sat_score AS DECIMAL)) AS avg_satisfaction_score
FROM doctor_patients_data d
JOIN hospital_er he ON d.patient_id = he.patient_id
GROUP BY d.doctor_name;


-- Question 19: Find Doctors with Diverse Patient Demographics

SELECT d.doctor_name, COUNT(DISTINCT he.patient_race) AS race_diversity, COUNT(he.patient_id) AS total_patients
FROM doctor_patients_data d
JOIN hospital_er he ON d.patient_id = he.patient_id
GROUP BY d.doctor_name
HAVING COUNT(DISTINCT he.patient_race) > 1;


-- Question 20: Calculate the Ratio of Total Bills Generated by Male to Female Patients per Department

SELECT d.department_referral,
    SUM(CASE WHEN he.patient_gender = 'M' THEN d.total_bill ELSE 0 END) AS male_total_bill,
    SUM(CASE WHEN he.patient_gender = 'F' THEN d.total_bill ELSE 0 END) AS female_total_bill,
    CASE 
        WHEN SUM(CASE WHEN he.patient_gender = 'F' THEN d.total_bill ELSE 0 END) = 0 THEN NULL
        ELSE ROUND(
            SUM(CASE WHEN he.patient_gender = 'M' THEN d.total_bill ELSE 0 END) /
            SUM(CASE WHEN he.patient_gender = 'F' THEN d.total_bill ELSE 0 END), 2)
    END AS male_female_bill_ratio
FROM doctor_patients_data d
JOIN hospital_er he ON d.patient_id = he.patient_id
GROUP BY d.department_referral;


-- Question 21: Update Patient Satisfaction Score for General Practice Department

-- First update any NULL or empty patient_sat_score to '0'
UPDATE hospital_er
SET patient_sat_score = '0'
WHERE patient_sat_score = '' OR patient_sat_score IS NULL;

-- Then add new column and process updates
ALTER TABLE hospital_er
ADD COLUMN original_patient_sat_score INT;

UPDATE hospital_er
SET original_patient_sat_score = CAST(patient_sat_score AS SIGNED);

UPDATE hospital_er
SET patient_sat_score = 
   CASE 
       WHEN original_patient_sat_score = 0 THEN '0'
       WHEN original_patient_sat_score + 2 > 10 THEN '10'
       ELSE CAST(original_patient_sat_score + 2 AS CHAR)
   END
WHERE department_referral = 'General Practice' AND patient_waittime > 30;

-- A selection query was executed to review the changes made

SELECT date, patient_id, department_referral, patient_waittime,
   original_patient_sat_score AS old_score,
   patient_sat_score AS new_score,
   CASE 
       WHEN original_patient_sat_score = 0 THEN '0'
       WHEN patient_sat_score != original_patient_sat_score THEN 'Updated'
       ELSE 'Not Updated'
   END AS update_status
FROM hospital_er
WHERE department_referral = 'General Practice'
ORDER BY 
   CASE 
       WHEN patient_sat_score != original_patient_sat_score THEN 1
       ELSE 2
   END,
   patient_waittime DESC;
