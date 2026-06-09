#Stage Aging Alert: Flag if deal value is error
CREATE OR REPLACE VIEW `zinc-cooler-491616-b5.project_2.pipeline_qa_alert` AS
select 
    organization AS account_name,
    country,
    latitude,
    longitude,
    industry,
    organization_size,
    owner,
    product,
    status,
    stage,
    deal_value,
    ROUND(probability/100, 2) as probability_rate,
    lead_acquisition_date,
    expected_close_date,
    actual_close_date,
  #how many days from acquisition to expected close date
    date_diff(lead_acquisition_date, expected_close_date, DAY) as pipeline_velocity,
  #Flag Data quality
    CASE
      WHEN deal_value < 0 then 'ERROR: Negative Deal Value'
      WHEN stage = 'Lost' and probability > 0 then 'ERROR: Lost Deal with Positive Probability'
      WHEN stage in ('Proposal sent', 'Opened') and expected_close_date < current_date() then 'WARNING: Overdue Expected Close Date'
      ELSE 'PASS'
    END as Data_Quality_Flag
from `zinc-cooler-491616-b5.project_2.B2B_sales`
