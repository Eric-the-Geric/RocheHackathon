
import streamlit as st
import joblib
from datetime import time
import pandas as pd
from sklearn.preprocessing import StandardScaler
import numpy as np
def app():
    st.title('Use a pre-trained model model to predict EOS')

    st.write('Please provide the data of the neonate so we can run inference')

    model = joblib.load("models/test.pkl")

    x2 = st.sidebar.slider("sex",0,1,0)
    x3 = st.sidebar.slider("birth_weight_kg",0.0, 6.0,)
    x4 = st.sidebar.slider("onset_age_in_days",0, 500, 10)
    x5 =st.sidebar.slider("onset_hour_of_day",0, 24)
    x6 = st.sidebar.slider("stat_abx",0, 1, 0)
    x7 = st.sidebar.slider("intubated_at_time_of_sepsis_evaluation",0, 1, 0)
    x8 = st.sidebar.slider("inotrope_at_time_of_sepsis_eval",0,1, 0)
    x9 = st.sidebar.slider("central_venous_line", 0, 1, 0)
    x10 = st.sidebar.slider("umbilical_arterial_line",0, 1, 0)
    x11 = st.sidebar.slider("ecmo",0, 1, 0)
    x12 = st.sidebar.slider("temp_celsius",30.0, 60.0, 36.8)
    x13 = st.sidebar.slider("comorbidity_necrotizing_enterocolitis",0, 1, 0)
    x14 = st.sidebar.slider("comorbidity_chronic_lung_disease",0, 1, 0)
    x15 = st.sidebar.slider("comorbidity_cardiac",0, 1, 0)
    x16 = st.sidebar.slider("comorbidity_surgical",0, 1, 0)
    x17 = st.sidebar.slider("comorbidity_ivh_or_shunt",0, 1, 0)


    list_intresting_parameters = [
        "sex",
        "birth_weight_kg",
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
        "comorbidity_ivh_or_shunt"
    ]
    values = [
     x2,
     x3,
     x4,
     x5,
     x6,
     x7,
     x8,
     x9,
     x10,
     x11,
     x12,
     x13,
     x14,
     x15,
     x16,
     x17]

    values = np.array(values)
    values= values[None,...]



    st.write(model.predict(values))
