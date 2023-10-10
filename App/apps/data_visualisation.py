import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
def countplot(df):
    if st.button("press to see the count plot"):
        fig = plt.figure(figsize=(10,4))
        st.write(" ### how balanced is the dataset ")
        sns.countplot(data=df, x="target")
        st.pyplot(fig)
def boxplot(df):
    name = st.selectbox("select a feature", df.columns.to_list())
    if st.button("press to see boxplot for any feature in the dataset"):
        fig = plt.figure(figsize=(6, 6))
        st.write(" ### compare the box plots for sepsis and non sepsis")
        sns.boxplot(data=df, y=name, x="target")
        st.pyplot(fig)
def violin(df):
    name = st.selectbox("select a feature", df.columns.to_list())
    if st.button("press to see violin plot for any feature in the dataset"):
        fig = plt.figure(figsize=(6, 6))
        st.write(" ### compare the box plots for sepsis and non sepsis")
        sns.violinplot(data=df, y=name, x="target")
        st.pyplot(fig)
def app():
    st.title("visualize Your Cleaned Dataset")

    # csv = st.sidebar.file_uploader("Please select the cleaned data")
    st.sidebar.write("1. Choose the cleaned dataset")
    data_path = st.sidebar.selectbox("select the training data", os.listdir("data/"))

    df = pd.read_csv("data/" + data_path)
    if st.button("press to see some of the dataset") and not st.button("hide"):
        st.write(df.head(10))
    plots = [{"plot": "count", "function": countplot}, {"plot": "boxplot", "function": boxplot}, {"plot": "violin", "function": violin}]

    plot = st.selectbox('Select a Plot', plots, format_func=lambda plot: plot['plot'])
    plot['function'](df)





