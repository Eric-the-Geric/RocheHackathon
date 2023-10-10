import os
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
from sklearn.feature_selection import SelectKBest, mutual_info_classif

def app():
    st.markdown("""
                # This is where we can train a model and select the best features
                - prototype phase right now
                - want to be able to select features and then in the interference we will want to be able to save those features and create sliders
                """)
    # Initialization
    st.session_state['train'] = 'false' 
    st.session_state['done'] = 'false'
    
    st.sidebar.write("1. Choose the cleaned dataset")
    data_path = st.sidebar.selectbox("select the training data", os.listdir("data/"))
    df = pd.read_csv("data/" +data_path)
    #csv = st.sidebar.file_uploader("select the dataset to train the model on")

    #if csv != None and not saved:
    name = st.text_input("What do you want to call your model?")

    # Read in the CSV
    #df = pd.read_csv(csv)

    # SPlit the data for train_test_split
    columns = df.columns.to_list()
    columns.remove('target')
    df_x = df[columns]
    df_y = df['target']


    st.sidebar.write("2. Select a model")
    models = [{"model": "gxboost", "object": XGBClassifier}, {"model": "forest", "object": RandomForestClassifier}, {"model": "Naive Bayes", "object": GaussianNB}]
    model = st.sidebar.selectbox('select a model to train', models, format_func=lambda model: model['model'])

    st.sidebar.write("3. Select a normalisation strategy")
    normalisation = [{"norm": "minmax", "object": MinMaxScaler}, {"norm": "StandardScaler", "object": StandardScaler}]
    norm = st.sidebar.selectbox('select a model to train', normalisation, format_func=lambda norm: norm['norm'])

    st.sidebar.write("4. Train test split")
    ratio = st.sidebar.slider('Percentage data left for model testing', 0.1, 0.4)

    st.sidebar.write("5. Select how many features the model selects")
    n_features = st.sidebar.slider('number of features', 3, len(columns))


    X_train, X_test, y_train, y_test = train_test_split(df_x, df_y, test_size=ratio, random_state=42)

    if st.button('press to train'):
        st.session_state['train'] = 'true'

    if st.session_state['train'] == 'true' and st.session_state['done'] == 'false':

        # Upsampling seems to do much better than downsampling
        smote = SMOTE(sampling_strategy="auto", random_state=42)
        X_train, y_train = smote.fit_resample(X_train, y_train)

# Now create a pipeline that we can save for inference
        pipe = make_pipeline(norm['object'](),SelectKBest(mutual_info_classif, k=n_features),model['object']())
        pipe.fit(X_train, y_train)
        st.session_state['done'] = 'true'
    if st.session_state['done'] == 'true':
        st.write(round(pipe.score(X_test, y_test), 2))
        st.dataframe(classification_report(pipe.predict(X_test), y_test, output_dict=True))

        cm = confusion_matrix(pipe.predict(X_test), y_test)
        plot_confusion_matrix(cm)

        feature_importances = permutation_importance(pipe, X_test, y_test, n_repeats=10, random_state=42)
        features = df_x.columns.to_list()
        plot_importance(features, feature_importances.importances_mean)

        download =  st.download_button("download the model", data=pickle.dumps(pipe), file_name=f"{name}.pkl")
        if download:
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

