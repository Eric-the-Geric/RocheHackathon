import streamlit as st
import pickle
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from xgboost import XGBClassifier
import seaborn as sns
import matplotlib.pyplot as plt
from imblearn.over_sampling import SMOTE
from imblearn.under_sampling import RandomUnderSampler
from sklearn.feature_selection import SelectFromModel
from sklearn.pipeline import make_pipeline
from sklearn.metrics import confusion_matrix, classification_report
from sklearn.inspection import permutation_importance
from sklearn.naive_bayes import GaussianNB

def app():
    st.markdown("""
                # This is where we can train a model and select the best features
                - prototype phase right now
                - want to be able to select features and then in the interference we will want to be able to save those features and create sliders
                """)
    
    st.sidebar.write("1. Choose the cleaned dataset")
    csv = st.sidebar.file_uploader("select the dataset to train the model on")
    trained_model = False
    saved = False

    if csv != None and not saved:
        name = st.text_input("What do you want to call your model?")

        # Read in the CSV
        df = pd.read_csv(csv)

        # SPlit the data for train_test_split
        df_x = df.iloc[:,:-1]
        df_y = df.iloc[:, -1]
        X_train, X_test, y_train, y_test = train_test_split(df_x, df_y, test_size=0.2, random_state=42)


        st.sidebar.write("2. Select a model")
        models = [{"model": "gxboost", "object": XGBClassifier}, {"model": "forest", "object": RandomForestClassifier}, {"model": "Naive Bayes", "object": GaussianNB}]
        model = st.sidebar.selectbox('select a model to train', models, format_func=lambda model: model['model'])
       

        st.sidebar.write("3. Select a normalisation strategy")
        normalisation = [{"norm": "minmax", "object": MinMaxScaler}, {"norm": "StandardScaler", "object": StandardScaler}]
        norm = st.sidebar.selectbox('select a model to train', normalisation, format_func=lambda norm: norm['norm'])

        # Upsampling seems to do much better than downsampling
        smote = SMOTE(sampling_strategy="auto", random_state=42)
        X_train, y_train = smote.fit_resample(X_train, y_train)

        # Now create a pipeline that we can save for inference
        pipe = make_pipeline(norm['object'](),model['object']() )
        pipe.fit(X_train, y_train)

        if st.button("show accuracy"):
            st.write(round(pipe.score(X_test, y_test), 2))
            st.write(classification_report(pipe.predict(X_test), y_test))

            cm = confusion_matrix(pipe.predict(X_test), y_test)
            plot_confusion_matrix(cm)
            trained_model = True

        if st.button("show feature importance"):
            feature_importances = permutation_importance(pipe, X_test, y_test, n_repeats=10, random_state=42)
            features = df_x.columns.to_list()
            plot_importance(features, feature_importances.importances_mean)

        if trained_model:
            download =  st.download_button("download the model", data=pickle.dumps(pipe), file_name=f"{name}.pkl")
            if download:
                saved = True
                st.write("congrats, the model was saved")

def plot_confusion_matrix(cm):
        fig = plt.figure(figsize=(6, 6))
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
        plt.title("Confusion Matrix for Model")
        plt.xlabel("Predicted class")
        plt.ylabel("True class")
        st.pyplot(fig)

def plot_importance(features, importances):
    fig = plt.figure(figsize=(10, 7))
    plt.bar(features, importances)
    plt.title("feature importance according to the trained model")
    plt.xlabel("features")
    plt.xticks(rotation=90)
    plt.ylabel("importance score")
    st.pyplot(fig)

