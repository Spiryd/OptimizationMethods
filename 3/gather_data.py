#!/usr/bin/env python3

from pathlib import Path
import pandas as pd

def main():
    # Mapping from our RCmax subfolders to BestKnown folders
    subfolder_map = {
        "instancias1a100":       "TXT CPLEX 2 horas de 10 a 100 log",
        "instanciasde10a100":    "TXT CPLEX 2 horas de 10 a 100 log",
        "instancias100a120":     "TXT Cplex 2 horas log U(100,120)",
        "instancias100a200":     "TXT Cplex 2 horas log U(100,200)",
        "Instanciasde1000a1100": "TXT Cplex 2 horas U(1000,1100)",
        "JobsCorre":             "TXT Cplex 2 horas log Jobs Corre",
        "MaqCorre":              "TXT Cplex 2 horas log Maq Corre"
    }

    # 1) Load all CPLEX .xls files under BestKnown/
    base_dir = Path("BestKnown")
    best_records = []
    for xls_path in base_dir.rglob("*.xls"):
        df = pd.read_excel(xls_path, engine="xlrd", dtype=str)
        # select & rename
        df = df[["Instance","Objective","Type","Gap","Time"]]
        df.columns = ["instance_file","best_objective","best_type","best_gap","best_time"]
        # convert numeric
        df["best_objective"] = pd.to_numeric(df["best_objective"], errors="coerce")
        df["best_type"]      = pd.to_numeric(df["best_type"], errors="coerce", downcast="integer")
        df["best_gap"]       = pd.to_numeric(df["best_gap"], errors="coerce", downcast="integer")
        df["best_time"]      = (
            df["best_time"]
              .str.replace(",", ".", regex=False)
              .pipe(pd.to_numeric, errors="coerce")
        )
        # instance_id from instance_file
        df["instance_id"] = df["instance_file"].str.replace(r"CPLEX\.txt$", "", regex=True)
        best_records.append(df[[
            "instance_id","best_objective","best_type","best_gap","best_time"
        ]])

    best_df = pd.concat(best_records, ignore_index=True)

    # 2) Load our algorithm's CSV summary
    alg_df = pd.read_csv("RCmax_summary.csv", dtype=str)

    # derive instance_id: remove '.txt' if filename present, else empty
    alg_df["instance_id"] = (
        alg_df["filename"]
          .fillna("")                
          .str.replace(r"\.txt$", "", regex=True)
    )

    # map to best_folder (if needed later)
    alg_df["best_folder"] = alg_df["subfolder"].map(subfolder_map)

    # convert algorithm metrics to numeric
    for col in [
        "n","m","T_lp","T_star","Cmax",
        "ratio_lp","ratio_st","time_lp","time_match"
    ]:
        alg_df[col] = pd.to_numeric(alg_df[col], errors="coerce")

    # 3) Merge on instance_id
    merged = alg_df.merge(
        best_df,
        on="instance_id",
        how="left"
    )

    # 4) Drop unneeded columns but keep filename
    merged = merged.drop(columns=[
        "instance_id","best_folder","instance_file"
    ], errors="ignore")

    # 5) Save merged results
    merged.to_csv("merged_results.csv", index=False)

if __name__ == "__main__":
    main()
