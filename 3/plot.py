#!/usr/bin/env python3

from pathlib import Path
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

def main():
    base_dir = Path(__file__).parent
    plots_dir = base_dir / "plots"
    plots_dir.mkdir(exist_ok=True)

    # Load the results
    df = pd.read_csv(base_dir / "merged_results.csv")
    df["diff"] = df["Cmax"] - df["best_objective"]

    # ---- Print basic numeric summaries ----
    print("\n=== Summary Statistics ===\n")

    summary = df[["ratio_lp", "Cmax", "T_lp", "time_lp", "time_match"]].describe()
    print(summary.T[["min", "mean", "50%", "max"]].rename(columns={"50%": "median"}))


    print("\nWorst 5 Approximation Ratios:")
    print(df.sort_values("ratio_lp", ascending=False)[["filename", "ratio_lp"]].head())

    print("\nBest 5 (Closest to LP Bound):")
    print(df.sort_values("ratio_lp")[["filename", "ratio_lp"]].head())

    # ---- Seaborn Theme ----
    sns.set_theme(style="whitegrid", context="talk")

    # --- Plot 1: Approximation Ratio by Family (Boxplot) ---
    plt.figure(figsize=(10, 6))
    ax = sns.boxplot(
        x="subfolder", y="ratio_lp", data=df,
        palette="Set2", showfliers=False
    )
    ax.set_title("Approximation Ratio (Cmax / LP) by Instance Family")
    ax.set_xlabel("Instance Family")
    ax.set_ylabel("Approximation Ratio")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(plots_dir / "ratio_boxplot_by_family.png", dpi=300)
    plt.close()

    # --- Plot 2: Ratio Histogram ---
    plt.figure(figsize=(8, 6))
    ax = sns.histplot(df["ratio_lp"].dropna(), bins=25, kde=True, color="steelblue")
    ax.set_title("Distribution of Approximation Ratios")
    ax.set_xlabel("Cmax / LP bound")
    ax.set_ylabel("Number of Instances")
    plt.tight_layout()
    plt.savefig(plots_dir / "ratio_histogram.png", dpi=300)
    plt.close()

    # --- Plot 3: Ratio vs. Number of Jobs ---
    plt.figure(figsize=(10, 6))
    ax = sns.scatterplot(
        x="n", y="ratio_lp", hue="subfolder",
        data=df, palette="tab10", alpha=0.85
    )
    ax.set_title("Approximation Ratio vs. Number of Jobs")
    ax.set_xlabel("Number of Jobs (n)")
    ax.set_ylabel("Approximation Ratio")
    plt.legend(title="Family", bbox_to_anchor=(1.05, 1), loc="upper left")
    plt.tight_layout()
    plt.savefig(plots_dir / "ratio_vs_n_scatter.png", dpi=300)
    plt.close()

    print("\n✅ Plots saved in:", plots_dir)

if __name__ == "__main__":
    main()
