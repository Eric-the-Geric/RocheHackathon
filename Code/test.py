import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.utils import class_weight
from imblearn.over_sampling import SMOTE
from sklearn.impute import KNNImputer
from sklearn.experimental import enable_hist_gradient_boosting
from sklearn.ensemble import HistGradientBoostingClassifier
import xgboost as xgb
from xgboost import XGBClassifier
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.impute import KNNImputer
import joblib
from imblearn.under_sampling import RandomUnderSampler

df = pd.read_csv("./Data/Kaggle_Dataset.csv")

list_non_invasive = ["HR", "O2Sat", "Temp", "FiO2", "Age", "Gender", "Resp"]

uebliche_messungen_neonatals = ["SBP", "MAP", "DBP", "EtCO2"]

list_invasive = list_non_invasive + uebliche_messungen_neonatals

df_interesting = df[list_invasive + ["SepsisLabel", "Patient_ID"]]


# Schritt 2: Daten vorbereiten
# Angenommen, df ist Ihr DataFrame
X = df_interesting.drop(columns=["SepsisLabel", "Patient_ID"])  # Merkmale
y = df_interesting["SepsisLabel"]  # Zielvariable
# Teilen Sie die Daten in Trainings- und Testsets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# Schritt 3: Unaufgeglichene Daten behandeln
# Anwendung von RandomUnderSampler
rus = RandomUnderSampler(random_state=42)
X_train_resampled, y_train_resampled = rus.fit_resample(X_train, y_train)

# Imputation nach dem Sampling
imputer = KNNImputer(n_neighbors=5)
X_train_filled = imputer.fit_transform(X_train_resampled)
X_test_filled = imputer.transform(X_test)

# Trainieren des Modells
clf = XGBClassifier(objective="binary:logistic", random_state=42)
clf.fit(X_train_filled, y_train_resampled)

joblib.dump(clf, "mein_modell.pkl")

# Schritt 5: Vorhersagen und Auswertung
y_pred = clf.predict(X_test_filled)
y_prob = clf.predict_proba(X_test_filled)[:, 1]


# # Schritt 4: Modell trainieren
# clf_smote = RandomForestClassifier(n_estimators=100, random_state=42)
# clf_smote.fit(X_train_resampled, y_train_resampled)

# # Schritt 5: Vorhersagen und Auswertung
# y_pred = clf.predict(X_test_filled)(-1))
# y_prob = clf.predict_proba(X_test_filled)[:, 1]

print("Klassifikationsbericht:")
print(classification_report(y_test, y_pred))

print("Konfusionsmatrix:")
print(confusion_matrix(y_test, y_pred))

print("ROC-AUC-Score:")
print(roc_auc_score(y_test, y_prob))

# Schritt 6: Merkmalswichtigkeiten
feature_importances = pd.DataFrame(
    clf.feature_importances_, index=X_train.columns, columns=["importance"]
).sort_values("importance", ascending=False)
print("Merkmalswichtigkeiten:")
print(feature_importances)
