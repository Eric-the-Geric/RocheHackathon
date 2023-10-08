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


def train_and_save_model(
    data_path,
    model_name="LR",
    sampling_method=None,
    split_ratio=0.3,
    feature_selection_method=None,
    saved_model="saved_model.pkl",
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

    # Feature selection
    if feature_selection_method == "SelectKBest":
        selector = SelectKBest(mutual_info_classif, k=number_of_features)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
        selected_features = [
            feature
            for feature, support in zip(X_train_scaled.columns, selector.get_support())
            if support
        ]

    elif feature_selection_method == "RFE":
        estimator = RandomForestClassifier()
        selector = RFE(estimator, 5)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
        selected_features = [
            feature
            for feature, ranking in zip(X_train_scaled.columns, selector.ranking_)
            if ranking == 1
        ]

    elif feature_selection_method == "FeatureImportance":
        model_for_importance = RandomForestClassifier()
        model_for_importance.fit(X_train_scaled, y_train)
        selector = SelectFromModel(model_for_importance, threshold=0.05)
        X_train_selected = selector.fit_transform(X_train_scaled, y_train)
        X_test_selected = selector.transform(X_test_scaled)
        selected_features = [
            feature
            for feature, support in zip(X_train_scaled.columns, selector.get_support())
            if support
        ]

    else:
        X_train_selected = X_train_scaled
        X_test_selected = X_test_scaled
        selected_features = X_train_scaled.columns.tolist()

    print("Selected Features:", selected_features)

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
    joblib.dump(model, saved_model)


if __name__ == "__main__":
    train_and_save_model(
        data_path="./Data/Neonatal.csv",
        model_name="LR",
        sampling_method="RandomUnderSampler",
        split_ratio=0.3,
        feature_selection_method="SelectKBest",
        saved_model="saved_model.pkl",
        number_of_features=5,
    )
