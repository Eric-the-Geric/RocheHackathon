import numpy as np
import pandas as pd
import streamlit as st
from apps.helpers import clean_data
def app():
# Web App Title
    st.markdown('''
# This page is used to create a cleaned dataset that is used for training the model 
    ---
    ''')

# Upload CSV data
    with st.sidebar.header('1. Upload your CSV data'):
        uploaded_file = st.sidebar.file_uploader("Upload your input CSV file that you would like to clean", type=["csv"])
        st.sidebar.markdown("""
    """)

# Pandas Profiling Report
    if uploaded_file is not None:
        @st.cache_data
        def load_csv():
            csv = pd.read_csv(uploaded_file)
            return csv
        df = load_csv()
        st.header('**Input DataFrame**')
        st.write(df.info())

        name = st.text_input("name of file to be saved")

        if st.button('Press to clean data'):
            if name == "":
                name = "neonatal"
                clean_data(df, "neonatal")
            else:
                clean_data(df, name)
            st.write("data has been saved")
    else:
        st.info('Awaiting for CSV file to be uploaded.')
