# ============================================================
# CREDIT RISK ML - FINAL VERSION
# Logistic Regression + Decision Tree + Random Forest
# ============================================================

# ============================================================
# 1. IMPORTS
# ============================================================

from snowflake.snowpark.context import get_active_session

import pandas as pd
import numpy as np

from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer

from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier

from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    confusion_matrix
)

import warnings
warnings.filterwarnings("ignore")


# ============================================================
# 2. SNOWFLAKE CONNECTION
# ============================================================

session = get_active_session()

session.sql("USE DATABASE CREDIT_RISK_DB").collect()
session.sql("USE SCHEMA CREDIT_RISK_GOLD").collect()

print("Connected to Snowflake")
print("Database:", session.get_current_database())
print("Schema:", session.get_current_schema())


# ============================================================
# 3. LOAD ML FEATURES
# ============================================================

df = session.table("ML_FEATURES")

print("Rows:", df.count())

print("\nColumns:")
print(df.columns)


# ============================================================
# 4. TARGET DISTRIBUTION
# ============================================================

target_distribution = session.sql("""
SELECT
    TARGET,
    COUNT(*) AS RECORD_COUNT,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS PERCENTAGE
FROM CREDIT_RISK_DB.CREDIT_RISK_GOLD.ML_FEATURES
GROUP BY TARGET
ORDER BY TARGET
""").to_pandas()

print("\nTarget Distribution:")
print(target_distribution)


# ============================================================
# 5. CONVERT TO PANDAS
# ============================================================

data = df.to_pandas()

print("\nDataset Shape:", data.shape)


# ============================================================
# 6. DEFINE FEATURES AND TARGET
# ============================================================

# TARGET = what we want to predict
# SK_ID_CURR = customer/application ID, so not used as feature

X = data.drop(columns=["TARGET", "SK_ID_CURR"])
y = data["TARGET"]

print("\nFeature Shape:", X.shape)
print("Target Shape:", y.shape)


# ============================================================
# 7. TRAIN / TEST SPLIT
# ============================================================

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    random_state=42,
    stratify=y
)

print("\nTraining Rows:", len(X_train))
print("Testing Rows:", len(X_test))


# ============================================================
# 8. IDENTIFY FEATURE TYPES
# ============================================================

numeric_features = X_train.select_dtypes(
    include=["int64", "float64", "int32", "float32"]
).columns.tolist()

categorical_features = X_train.select_dtypes(
    include=["object", "category", "bool"]
).columns.tolist()

print("\nNumeric Features:", len(numeric_features))
print("Categorical Features:", len(categorical_features))


# ============================================================
# 9. PREPROCESSING
# ============================================================

numeric_transformer = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler())
    ]
)

categorical_transformer = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="most_frequent")),
        (
            "onehot",
            OneHotEncoder(
                handle_unknown="ignore",
                sparse_output=False
            )
        )
    ]
)

preprocessor = ColumnTransformer(
    transformers=[
        ("num", numeric_transformer, numeric_features),
        ("cat", categorical_transformer, categorical_features)
    ]
)


# ============================================================
# 10. PREPROCESS DATA
# ============================================================

X_train_processed = preprocessor.fit_transform(X_train)
X_test_processed = preprocessor.transform(X_test)

print("\nProcessed Train Shape:", X_train_processed.shape)
print("Processed Test Shape:", X_test_processed.shape)


# ============================================================
# 11. MODEL EVALUATION FUNCTION
# ============================================================

def evaluate_model(model_name, model, X_test_data, y_test_data):

    predictions = model.predict(X_test_data)

    probabilities = model.predict_proba(X_test_data)[:, 1]

    accuracy = accuracy_score(y_test_data, predictions)
    precision = precision_score(
        y_test_data,
        predictions,
        zero_division=0
    )
    recall = recall_score(
        y_test_data,
        predictions,
        zero_division=0
    )
    f1 = f1_score(
        y_test_data,
        predictions,
        zero_division=0
    )
    roc_auc = roc_auc_score(
        y_test_data,
        probabilities
    )

    cm = confusion_matrix(
        y_test_data,
        predictions
    )

    print("\n" + "=" * 60)
    print(model_name)
    print("=" * 60)

    print("Accuracy :", round(accuracy * 100, 2), "%")
    print("Precision:", round(precision * 100, 2), "%")
    print("Recall   :", round(recall * 100, 2), "%")
    print("F1 Score :", round(f1 * 100, 2), "%")
    print("ROC-AUC  :", round(roc_auc * 100, 2), "%")

    print("\nConfusion Matrix:")
    print(cm)

    return {
        "Model": model_name,
        "Accuracy": accuracy * 100,
        "Precision": precision * 100,
        "Recall": recall * 100,
        "F1": f1 * 100,
        "ROC-AUC": roc_auc * 100
    }


# ============================================================
# 12. LOGISTIC REGRESSION - NORMAL
# ============================================================

logistic_model = LogisticRegression(
    class_weight="balanced",
    max_iter=1000,
    random_state=42
)

logistic_model.fit(
    X_train_processed,
    y_train
)

logistic_result = evaluate_model(
    "Logistic Regression",
    logistic_model,
    X_test_processed,
    y_test
)


# ============================================================
# 13. DECISION TREE - NORMAL
# ============================================================

decision_tree_model = DecisionTreeClassifier(
    max_depth=8,
    class_weight="balanced",
    random_state=42
)

decision_tree_model.fit(
    X_train_processed,
    y_train
)

decision_tree_result = evaluate_model(
    "Decision Tree",
    decision_tree_model,
    X_test_processed,
    y_test
)


# ============================================================
# 14. RANDOM FOREST - NORMAL ONLY
# ============================================================

# IMPORTANT:
# No Random Forest tuning here.

random_forest_model = RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
    class_weight="balanced",
    random_state=42,
    n_jobs=-1
)

random_forest_model.fit(
    X_train_processed,
    y_train
)

random_forest_result = evaluate_model(
    "Random Forest",
    random_forest_model,
    X_test_processed,
    y_test
)


# ============================================================
# 15. NORMAL MODEL COMPARISON
# ============================================================

normal_results = pd.DataFrame([
    logistic_result,
    decision_tree_result,
    random_forest_result
])

print("\n")
print("=" * 80)
print("NORMAL MODEL COMPARISON")
print("=" * 80)

print(
    normal_results.round(2).to_string(index=False)
)


# ============================================================
# 16. TUNE LOGISTIC REGRESSION
# ============================================================

print("\n" + "=" * 60)
print("TUNING LOGISTIC REGRESSION")
print("=" * 60)

logistic_param_grid = {
    "C": [0.01, 0.1, 1, 10],
    "class_weight": ["balanced", None]
}

logistic_tuned = GridSearchCV(
    LogisticRegression(
        max_iter=1000,
        random_state=42
    ),
    param_grid=logistic_param_grid,
    scoring="roc_auc",
    cv=3,
    n_jobs=-1
)

logistic_tuned.fit(
    X_train_processed,
    y_train
)

print("Best Logistic Parameters:")
print(logistic_tuned.best_params_)

print(
    "Best CV ROC-AUC:",
    round(logistic_tuned.best_score_ * 100, 2),
    "%"
)


# ============================================================
# 17. EVALUATE TUNED LOGISTIC
# ============================================================

tuned_logistic_result = evaluate_model(
    "Tuned Logistic Regression",
    logistic_tuned,
    X_test_processed,
    y_test
)


# ============================================================
# 18. TUNE DECISION TREE
# ============================================================

print("\n" + "=" * 60)
print("TUNING DECISION TREE")
print("=" * 60)

tree_param_grid = {
    "max_depth": [5, 8, 12, 16],
    "min_samples_split": [2, 10, 20],
    "class_weight": ["balanced", None]
}

tree_tuned = GridSearchCV(
    DecisionTreeClassifier(
        random_state=42
    ),
    param_grid=tree_param_grid,
    scoring="roc_auc",
    cv=3,
    n_jobs=-1
)

tree_tuned.fit(
    X_train_processed,
    y_train
)

print("Best Decision Tree Parameters:")
print(tree_tuned.best_params_)

print(
    "Best CV ROC-AUC:",
    round(tree_tuned.best_score_ * 100, 2),
    "%"
)


# ============================================================
# 19. EVALUATE TUNED DECISION TREE
# ============================================================

tuned_tree_result = evaluate_model(
    "Tuned Decision Tree",
    tree_tuned,
    X_test_processed,
    y_test
)


# ============================================================
# 20. FINAL MODEL COMPARISON
# ============================================================

final_comparison_df = pd.DataFrame([
    tuned_logistic_result,
    tuned_tree_result,
    random_forest_result
])

print("\n")
print("=" * 80)
print("FINAL MODEL COMPARISON")
print("=" * 80)

print(
    final_comparison_df.round(2).to_string(index=False)
)


# ============================================================
# 21. SELECT FINAL MODEL
# ============================================================

model_objects = {
    "Tuned Logistic Regression": logistic_tuned,
    "Tuned Decision Tree": tree_tuned,
    "Random Forest": random_forest_model
}

final_model_name = final_comparison_df.loc[
    final_comparison_df["ROC-AUC"].idxmax(),
    "Model"
]

final_model = model_objects[final_model_name]

print("\n" + "=" * 60)
print("FINAL MODEL")
print("=" * 60)

print("Selected Model:", final_model_name)

print(
    "Reason: Highest ROC-AUC among the compared models."
)


# ============================================================
# 22. FINAL PREDICTIONS
# ============================================================

final_predictions = final_model.predict(
    X_test_processed
)

final_probabilities = final_model.predict_proba(
    X_test_processed
)[:, 1]


# ============================================================
# 23. CREATE PREDICTION TABLE
# ============================================================

test_ids = data.loc[
    X_test.index,
    "SK_ID_CURR"
]

prediction_df = pd.DataFrame({
    "SK_ID_CURR": test_ids.values,
    "ACTUAL_TARGET": y_test.values,
    "PREDICTED_TARGET": final_predictions,
    "DEFAULT_PROBABILITY": final_probabilities
})


# ============================================================
# 24. RISK LEVEL
# ============================================================

prediction_df["RISK_LEVEL"] = prediction_df[
    "PREDICTED_TARGET"
].map({
    0: "LOW_RISK",
    1: "HIGH_RISK"
})


print("\nPrediction Sample:")
print(prediction_df.head(10))


# ============================================================
# 25. PREDICTION SUMMARY
# ============================================================

print("\n" + "=" * 60)
print("PREDICTION SUMMARY")
print("=" * 60)

print(
    prediction_df["PREDICTED_TARGET"]
    .value_counts()
    .sort_index()
)

print("\nRisk Level:")
print(
    prediction_df["RISK_LEVEL"]
    .value_counts()
)


# ============================================================
# 26. FINAL MODEL PERFORMANCE
# ============================================================

final_accuracy = accuracy_score(
    y_test,
    final_predictions
)

final_precision = precision_score(
    y_test,
    final_predictions,
    zero_division=0
)

final_recall = recall_score(
    y_test,
    final_predictions,
    zero_division=0
)

final_f1 = f1_score(
    y_test,
    final_predictions,
    zero_division=0
)

final_roc_auc = roc_auc_score(
    y_test,
    final_probabilities
)

final_cm = confusion_matrix(
    y_test,
    final_predictions
)

print("\n" + "=" * 60)
print("FINAL MODEL PERFORMANCE")
print("=" * 60)

print("Model    :", final_model_name)
print("Accuracy :", round(final_accuracy * 100, 2), "%")
print("Precision:", round(final_precision * 100, 2), "%")
print("Recall   :", round(final_recall * 100, 2), "%")
print("F1 Score :", round(final_f1 * 100, 2), "%")
print("ROC-AUC  :", round(final_roc_auc * 100, 2), "%")

print("\nConfusion Matrix:")
print(final_cm)


# ============================================================
# 27. FEATURE IMPORTANCE
# ============================================================

feature_names = preprocessor.get_feature_names_out()

if final_model_name == "Random Forest":

    importance_values = final_model.feature_importances_

elif final_model_name == "Tuned Decision Tree":

    importance_values = (
        final_model.best_estimator_
        .feature_importances_
    )

else:

    importance_values = np.abs(
        final_model.best_estimator_.coef_[0]
    )


feature_importance_df = pd.DataFrame({
    "FEATURE_NAME": feature_names,
    "IMPORTANCE": importance_values
})

feature_importance_df = (
    feature_importance_df
    .sort_values(
        "IMPORTANCE",
        ascending=False
    )
    .head(20)
    .reset_index(drop=True)
)

print("\n" + "=" * 60)
print("TOP 20 IMPORTANT FEATURES")
print("=" * 60)

print(
    feature_importance_df.to_string(index=False)
)


# ============================================================
# 28. SAVE PREDICTIONS TO SNOWFLAKE
# ============================================================

session.write_pandas(
    prediction_df,
    "CREDIT_RISK_PREDICTIONS",
    auto_create_table=True,
    overwrite=True
)

print(
    "\nCREDIT_RISK_PREDICTIONS table created successfully."
)


# ============================================================
# 29. SAVE FEATURE IMPORTANCE TO SNOWFLAKE
# ============================================================

session.write_pandas(
    feature_importance_df,
    "CREDIT_RISK_FEATURE_IMPORTANCE",
    auto_create_table=True,
    overwrite=True
)

print(
    "CREDIT_RISK_FEATURE_IMPORTANCE table created successfully."
)


# ============================================================
# 30. VERIFY TABLES
# ============================================================

print("\n" + "=" * 60)
print("FINAL SNOWFLAKE TABLE CHECK")
print("=" * 60)

prediction_count = session.sql("""
SELECT COUNT(*)
FROM CREDIT_RISK_DB.CREDIT_RISK_GOLD.CREDIT_RISK_PREDICTIONS
""").collect()[0][0]

importance_count = session.sql("""
SELECT COUNT(*)
FROM CREDIT_RISK_DB.CREDIT_RISK_GOLD.CREDIT_RISK_FEATURE_IMPORTANCE
""").collect()[0][0]

print(
    "Prediction rows:",
    prediction_count
)

print(
    "Feature importance rows:",
    importance_count
)


# ============================================================
# 31. FINAL MESSAGE
# ============================================================

print("\n" + "=" * 80)
print("CREDIT RISK ML COMPLETED SUCCESSFULLY")
print("=" * 80)

print("Final Model:", final_model_name)
print("Main Prediction: DEFAULT_PROBABILITY")
print("Binary Prediction: PREDICTED_TARGET")
print("Business Label: RISK_LEVEL")

