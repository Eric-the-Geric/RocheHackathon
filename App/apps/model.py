import streamlit as st
import joblib
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import MinMaxScaler
from xgboost import XGBClassifier
import seaborn as sns
import matplotlib.pyplot as plt
from imblearn.over_sampling import SMOTE
from imblearn.under_sampling import RandomUnderSampler
def app():
    st.markdown("""
                # This is where we can train a model and select the best features
                - prototype phase right now
                - want to be able to select features and then in the interference we will want to be able to save those features and create sliders
                """)
    
    csv = st.file_uploader("select the dataset to train the model on")

    if csv not None:
        df = pd.read_csv(csv)
        df_x = df.iloc[:-1]
        df_y = df.iloc[-1]
        all_columns = df.columns.to_list()

    #model = joblib.load("models/saved_model.pkl")
def plot_confusion_matrix(cm, model_name):
    if st.button("press to see confusion matrix"):
        fig = plt.figure(figsize=(6, 6))
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
        plt.title(f"Confusion Matrix for Model")
        plt.xlabel("Predicted class")
        plt.ylabel("True class")
        st.pyplot(fig)
