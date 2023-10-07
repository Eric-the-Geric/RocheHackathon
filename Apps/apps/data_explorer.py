import numpy as np
import pandas as pd
import streamlit as st

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
        st.write('---')
        st.header('**Pandas Profiling Report**')

        if st.button('Press to clean data'):
            print("button pressed")
    else:
        st.info('Awaiting for CSV file to be uploaded.')
