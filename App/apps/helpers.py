
import pandas as pd
import numpy as np
import pathlib

# ML imports
import pandas as pd
from sklearn.model_selection import train_test_split
from imblearn.over_sampling import SMOTE
from imblearn.under_sampling import RandomUnderSampler
from sklearn.utils import resample
from sklearn.preprocessing import StandardScaler
from sklearn.feature_selection import (
    RFE,
    SelectKBest,
    mutual_info_classif,
    SelectFromModel,
)
from sklearn.linear_model import LogisticRegression
from sklearn.svm import SVC
from xgboost import XGBClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.metrics import accuracy_score
import joblib

def map_to_binary(value):
    if value == 1 or value in [4, 5]:
        return 1
    else:
        return 0


def clean_data(df, name, list_intresting_parameters, pred_col):
    """ inputs:
            df: dataframe to clean
            name: string to save to csv
            list_intresting_parameters: columns to use

       outputs:
           saves a csv

    -Converts a the sepsis group to binary for easier classification
    - groups all NaN values

    """
    df = df[(list_intresting_parameters+[pred_col])]
    df.replace("NI", np.nan, inplace=True)
    df["target"] = df[pred_col]
    df = df.drop(columns=[pred_col])
    df = df.dropna()
    df.to_csv(f"data/{name}.csv", index=False)

def train_and_save_model(
    data_path,
    model_name="LR",
    sampling_method=None,
    split_ratio=0.3,
    feature_selection_method=None,
    model_path="saved_model.pkl",
    number_of_features=5,
):
    data = pd.read_csv(data_path)

    # Splitting data
    X = data[data.columns.difference(["sepsis_binary", "sepsis_group"])]
    y = data["sepsis_binary"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=split_ratio, random_state=42
    )

    # Sampling
    if sampling_method == "RandomUnderSampler":
        rus = RandomUnderSampler(random_state=42)
        X_train, y_train = rus.fit_resample(X_train, y_train)
    elif sampling_method == "RandomOverSampler":
        smote = SMOTE(random_state=42)
        X_train, y_train = smote.fit_resample(X_train, y_train)
    elif sampling_method == "Upsampling":
        # Upsample the minority class
        X_upsampled, y_upsampled = resample(
            X_train[y_train == 1],
            y_train[y_train == 1],
            replace=True,
            n_samples=len(y_train[y_train == 0]),
            random_state=42,
        )
        X_train = pd.concat([X_train, X_upsampled])
        y_train = pd.concat([y_train, y_upsampled])

    # Scaling
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Feature Selection
    if feature_selection_method == "SelectKBest":
        selector = SelectKBest(mutual_info_classif, k=number_of_features)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
    elif feature_selection_method == "RFE":
        estimator = RandomForestClassifier()
        selector = RFE(estimator, 5)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
    elif feature_selection_method == "FeatureImportance":
        model_for_importance = RandomForestClassifier()
        model_for_importance.fit(X_train_scaled, y_train)
        selector = SelectFromModel(model_for_importance, threshold=0.05)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
    else:
        X_train_selected = X_train_scaled
        X_test_selected = X_test_scaled

    # Model initialization and training
    models = {
        "LR": LogisticRegression(),
        "SVM": SVC(),
        "XGBoost": XGBClassifier(eval_metric="mlogloss"),
        "RF": RandomForestClassifier(),
        "DT": DecisionTreeClassifier(),
        "NB": GaussianNB(),
    }

    model = models[model_name]
    model.fit(X_train_selected, y_train)

    # Predictions and evaluation
    y_pred = model.predict(X_test_selected)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"{model_name}: {accuracy}")

    # Save the model
    #joblib.dump(model, model_path)
