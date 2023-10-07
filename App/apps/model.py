import streamlit as st
import joblib


def app():
    st.title('Model')

    st.write('This is the `Model` page of the multi-page app.')

    st.write('The model performance of the Iris dataset is presented below.')

    model = joblib.load("models/saved_model.pkl")

