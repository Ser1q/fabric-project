# Microsoft Fabric — Unified Analytics Platform

A full-stack data engineering project integrating **NYC Taxi**, **OpenAQ air quality**,
**World Bank GDP**, **ECB FX rates**, and **OpenWeatherMap** into a medallion
lakehouse on Microsoft Fabric, with a time-series weather pipeline (TimescaleDB + Grafana)
and automated data quality checks via Great Expectations + a Telegram bot.

---

## Architecture overview

```
External Sources
  ├── TLC Parquet (monthly)   ─┐
  ├── OpenAQ API (daily)       │
  ├── World Bank API (yearly)  ├──► Bronze Lakehouse
  ├── ECB FX CSV (daily)       │      (raw Delta tables)
  └── OpenWeatherMap (hourly) ─┘
              │
              ▼ PySpark Notebooks
         Silver Lakehouse
         (cleaned Delta tables)
              │
              ▼ PySpark Notebooks
         Gold Lakehouse + Fabric Warehouse
         (star schema: Facts + Dims)
              │
       ┌──────┴───────────────┐
       ▼                      ▼
  Power BI Dashboards    TimescaleDB
  (Fabric-native)        (weather_metrics hypertable)
                              │
                              ▼
                         Grafana Dashboards
                         (weather + taxi overlay)

  Great Expectations ──► Telegram Bot
  (quality checks)       (/quality_report command)
```

---

## Repo structure

```
fabric_project/
├── notebooks/
│   ├── bronze/                       
│   ├── silver/                     
│   └── gold/                         
├── pipelines/                        
├── ge_suites/                        
├── grafana_dashboards/               
├── bot/                             
├── config/
│   └── settings.py                  
├── scripts/
│   └── init_timescaledb.sql         
├── docs/
│   ├── secret_setup.md
│   └── data_dictionary.md           
├── .env.example                     
├── docker-compose.yml              
└── requirements.txt
```

---

## API keys needed
OpenAQ, OpenWeatherMap, Telegram Bot

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Data platform | Microsoft Fabric (Lakehouse, Warehouse, Notebooks, Pipelines) |
| Processing | PySpark 3.5, Delta Lake |
| Time-series DB | TimescaleDB (PostgreSQL 16) |
| Visualization | Power BI, Grafana |
| Data quality | Great Expectations 0.18 |
| Bot | python-telegram-bot 21 |
| Config | pydantic-settings, Azure Key Vault |
| Dev services | Docker Compose |
