#!/usr/bin/env python3

from pathlib import Path
import pandas as pd

def main():
    # Mapping from RCmax subfolder → corresponding BestKnown folder
    subfolder_map = {
        "instancias1a100":       "TXT CPLEX 2 horas de 10 a 100 log",
        "instanciasde10a100":    "TXT CPLEX 2 horas de 10 a 100 log",
        "instancias100a120":     "TXT Cplex 2 horas log U(100,120)",
        "instancias100a200":     "TXT Cplex 2 horas log U(100,200)",
        "Instanciasde1000a1100": "TXT Cplex 2 horas U(1000,1100)",
        "JobsCorre":             "TXT Cplex 2 horas log Jobs Corre",
        "MaqCorre":              "TXT Cplex 2 horas log Maq Corre"
    }

    # 1) Load all BestKnown CPLEX .xls files, keeping track of their folder
    base_dir = Path("BestKnown")
    best_records = []
    for xls_path in base_dir.rglob("*.xls"):
        folder_name = xls_path.parent.name
        df = pd.read_excel(xls_path, engine="xlrd", dtype=str)

        # Standardize column names and types
        df = df[["Instance", "Objective", "Type", "Gap", "Time"]]
        df.columns = ["instance_file", "best_objective", "best_type", "best_gap", "best_time"]

        df["best_objective"] = pd.to_numeric(df["best_objective"], errors="coerce")
        df["best_type"]      = pd.to_numeric(df["best_type"], errors="coerce", downcast="integer")
        df["best_gap"]       = pd.to_numeric(df["best_gap"], errors="coerce", downcast="integer")
        df["best_time"]      = (
            df["best_time"]
              .str.replace(",", ".", regex=False)
              .pipe(pd.to_numeric, errors="coerce")
        )

        # Add folder column for uniqueness
        df["best_folder"] = folder_name

        best_records.append(df[[
            "instance_file", "best_folder", "best_objective", "best_type", "best_gap", "best_time"
        ]])

    best_df = pd.concat(best_records, ignore_index=True)

    # Remove duplicates, keeping the lowest objective value for each (instance_file, best_folder)
    best_df = (
        best_df.sort_values("best_objective")
               .drop_duplicates(subset=["instance_file", "best_folder"], keep="first")
    )

    # 2) Load our RCmax summary output
    alg_df = pd.read_csv("RCmax_summary.csv", dtype=str)

    # Map instance source folders to best_folder
    alg_df["best_folder"] = alg_df["subfolder"].map(subfolder_map)

    # Convert numeric columns
    for col in ["n", "m", "T_star", "Cmax", "ratio"]:
        alg_df[col] = pd.to_numeric(alg_df[col], errors="coerce")

    # --- Debug: Print samples and check for mismatches ---
    print("alg_df['filename'] sample:", alg_df['filename'].unique()[:5])
    print("best_df['instance_file'] sample:", best_df['instance_file'].unique()[:5])
    print("alg_df['best_folder'] sample:", alg_df['best_folder'].unique())
    print("best_df['best_folder'] sample:", best_df['best_folder'].unique())

    # Standardize filenames: strip, lowercase, remove 'cplex', and ensure .txt extension for both
    alg_df['filename_std'] = alg_df['filename'].str.strip().str.lower()
    best_df['instance_file_std'] = (
        best_df['instance_file']
        .str.strip()
        .str.lower()
        .str.replace('cplex', '', regex=False)  # Remove 'cplex'
        .str.replace(' ', '', regex=False)      # Remove any spaces left
    )

    # If needed, add .txt extension to best_df (if missing), handle NaN safely
    best_df['instance_file_std'] = best_df['instance_file_std'].apply(
        lambda x: x if isinstance(x, str) and x.endswith('.txt') else (x + '.txt' if isinstance(x, str) else x)
    )
    alg_df['filename_std'] = alg_df['filename_std'].apply(
        lambda x: x if isinstance(x, str) and x.endswith('.txt') else (x + '.txt' if isinstance(x, str) else x)
    )

    # Print intersection for debugging
    print("Matching filenames:", set(alg_df['filename_std']).intersection(set(best_df['instance_file_std'])))
    print("Matching folders:", set(alg_df['best_folder']).intersection(set(best_df['best_folder'])))

    # 3) Merge on standardized (filename, best_folder)
    merged = alg_df.merge(
        best_df,
        left_on=["filename_std", "best_folder"],
        right_on=["instance_file_std", "best_folder"],
        how="left"
    )

    # Drop rows where instance_file is NaN (no match in best-known data)
    merged = merged[~merged["instance_file"].isna()]

    # 4) Drop unused technical fields
    merged = merged.drop(columns=[
        "instance_file", "best_folder", "filename_std", "instance_file_std"
    ], errors="ignore")

    # 5) Save final merged result for plotting
    merged.to_csv("merged_results.csv", index=False)

    print("✅ merged_results.csv saved with", len(merged), "rows.")

if __name__ == "__main__":
    main()
