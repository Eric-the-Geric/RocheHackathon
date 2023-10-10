
import streamlit as st
import joblib
from datetime import time
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

def app():
    st.title('Use a pre-trained model model to predict Sepsis')
    
    model_path = st.selectbox("select a model", os.listdir("models/"))
    model = joblib.load(f"models/{model_path}")

    data_path = st.selectbox("select the training data", os.listdir("data/"))
    df = pd.read_csv("data/" +data_path)
    df = df.iloc[:, :-1]
    columns = df.columns.to_list()
    st.sidebar.write("Please adjust the following sliders to match the concerned neonate")
    feature_count = []
    for i, col in enumerate(columns):
        feature_count.append(st.sidebar.slider(col, df[col].min(), df[col].max()))

    values = []
    for i in range(len(feature_count)):
        values.append(feature_count[i])
    values = np.array(values)
    values = values[None,...]

    #if st.button("Press to run inference"):
    prediction = model.predict_proba(values)
    st.write(f"# Prediction for Sepsis: {prediction[0,1]*100:.2f}%")

    if prediction[0,0] < prediction[0,1]:
        st.write("# Model has predicted Sepsis likely. Please take nessecary action")
        st.image(plt.imread('images/Danger.jpg'))

    else: 
        st.markdown("# Model has predicted Sepsis NOT likely but continue to monitor symptoms")



