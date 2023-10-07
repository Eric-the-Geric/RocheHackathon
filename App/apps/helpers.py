
import pandas as pd
import numpy as np
import pathlib


def map_to_binary(value):
    if value == 1 or value in [4, 5]:
        return 1
    else:
        return 0


def clean_data(df, name):
    list_intresting_parameters = [
        "sex",
        "birth_weight_kg",
        "sepsis_group",
        "onset_age_in_days",
        "onset_hour_of_day",
        "stat_abx",
        "intubated_at_time_of_sepsis_evaluation",
        "inotrope_at_time_of_sepsis_eval",
        "central_venous_line",
        "umbilical_arterial_line",
        "ecmo",
        "temp_celsius",
        "comorbidity_necrotizing_enterocolitis",
        "comorbidity_chronic_lung_disease",
        "comorbidity_cardiac",
        "comorbidity_surgical",
        "comorbidity_ivh_or_shunt",
    ]
    df = df[list_intresting_parameters]
    df.replace("NI", np.nan, inplace=True)
    df = df[df["sepsis_group"] != 6]
    df["sepsis_binary"] = df["sepsis_group"].apply(map_to_binary)
    df = df.drop(columns=["sepsis_group"])
    df = df.dropna()
    df.to_csv(f"data/{name}.csv", index=False)
