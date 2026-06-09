CREATE OR REPLACE TABLE `zinc-cooler-491616-b5.project_2.performance` as
with industry_metrics as(
  select industry, 
        country,
        owner as sales_rep_name,
  #Calculate ACTUAL revenue from successful cases
        sum(case when stage = 'Won' then deal_value else 0 end) as closed_won_revenue,
  #Calculate PREDICTED revenue from other cases than successful and lost
        sum(case when stage not in ('Won', 'Lost') then deal_value*probability_rate else 0 end) as predicted_revenue,
  #Count successful cases
        sum(case when stage = 'Won' then 1 else 0 end) as won_deals_count,
        count(*) as total_deals
  FROM `zinc-cooler-491616-b5.project_2.pipeline_qa_alert`
  where Data_Quality_Flag!='ERROR: Negative Deal Value'
  GROUP BY industry, country, sales_rep_name
)
select industry,
        country,
        sales_rep_name,
        closed_won_revenue,
        round(predicted_revenue, 2) as predicted_revenue,
        total_deals,
    #Calculate Win Rate %
        round(won_deals_count/total_deals * 100,2) as win_rate_percentage,
    #Rank Sales Rep based on Country
        rank() over (partition by country order by closed_won_revenue desc) as rep_rank_in_country
from industry_metrics

