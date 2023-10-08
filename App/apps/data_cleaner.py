import numpy as np
import pandas as pd
import streamlit as st
from apps.helpers import clean_data
def app():
# Web App Title
    st.markdown('''
# Clean a EOS data set 
    ''')

# Upload CSV data
    with st.sidebar.header('Upload your CSV data'):
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

        columns = df.columns.tolist()
        st.write("Please select which columns you would like the model to train on")
        selected_columns = st.multiselect("columns of the df", columns)
        if "sepsis_group" not in selected_columns:
            selected_columns.append("sepsis_group")

        name = st.text_input("name of file to be saved")

        if st.button('Press to clean data'):
            if name == "":
                name = "neonatal"
                df = clean_data(df, "neonatal", selected_columns)
            else:
                df = clean_data(df, name, selected_columns)
            st.write("data has been saved")
    else:
        st.info('Awaiting for CSV file to be uploaded.')


