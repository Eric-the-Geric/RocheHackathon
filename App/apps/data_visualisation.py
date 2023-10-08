import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def countplot(df):
    if st.button("press to see the count plot"):
        fig = plt.figure(figsize=(10,4))
        st.write(" ### how balanced is the dataset ")
        sns.countplot(data=df, x="sepsis_binary")
        st.pyplot(fig)
def boxplot(df):
    name = st.selectbox("select a feature", df.columns.to_list())
    if st.button("press to see boxplot for any feature in the dataset"):
        fig = plt.figure(figsize=(6, 6))
        st.write(" ### compare the box plots for sepsis and non sepsis")
        sns.boxplot(data=df, y=name, x="sepsis_binary")
        st.pyplot(fig)
def app():
    st.title("visualize Your Cleaned Dataset")

    csv = st.file_uploader("Please select the cleaned data")

    if csv is not None:

        df = pd.read_csv(csv)
        st.write(df.head(10))
        countplot(df)
        boxplot(df)








