import numpy as np
import pandas as pd
import streamlit as st

def app():
# Web App Title
    st.markdown('''
# **The EDA App**

    This is the **EDA App** created in Streamlit using the **pandas-profiling** library.

    **Credit:** App built in `Python` + `Streamlit` by [Chanin Nantasenamat](https://medium.com/@chanin.nantasenamat) (aka [Data Professor](http://youtube.com/dataprofessor))

    ---
    ''')

# Upload CSV data
    with st.sidebar.header('1. Upload your CSV data'):
        uploaded_file = st.sidebar.file_uploader("Upload your input CSV file", type=["csv"])
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
        st.write(df.head(100))
        st.write('---')
        st.header('**Pandas Profiling Report**')
    else:
        st.info('Awaiting for CSV file to be uploaded.')
