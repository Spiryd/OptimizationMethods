#!/usr/bin/env python3

from pathlib import Path
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

def main():
    base_dir = Path(__file__).parent
    plots_dir = base_dir / "plots"
    plots_dir.mkdir(exist_ok=True)

    # === Load merged results ===
    df = pd.read_csv(base_dir / "merged_results.csv")

    # === Ensure correct dtypes ===
    df["ratio"] = pd.to_numeric(df["ratio"], errors="coerce")
    df["Cmax"] = pd.to_numeric(df["Cmax"], errors="coerce")
    df["T_star"] = pd.to_numeric(df["T_star"], errors="coerce")
    df["n"] = pd.to_numeric(df["n"], errors="coerce")
    df["best_objective"] = pd.to_numeric(df["best_objective"], errors="coerce")

    # === After loading & type conversions ===
    # Compute difference between our Cmax and the best known objective
    df["diff"] = df["Cmax"] - df["best_objective"]

    # === New Summary Statistics ===
    print("\n=== Summary Statistics ===\n")
    summary = df[["diff", "Cmax", "ratio"]].describe()
    print(summary.T[["min", "mean", "50%", "max"]].rename(columns={"50%": "median"}))

    # ——— Worst 5 by diff (largest positive gap) ———
    worst5_diff = df.nlargest(5, "diff")[["filename", "best_objective", "Cmax", "diff"]]
    print("\nWorst 5 by Diff (Cmax – Best):")
    print(worst5_diff.to_string(index=False))

    # ——— Best 5 (smallest non‐negative diff) ———
    # Filter out any negative diffs, then take 5 smallest
    best5_diff = df.nsmallest(5, "diff")[["filename", "best_objective", "Cmax", "diff"]]
    print("\nBest 5 by Diff (Cmax – Best):")
    print(best5_diff.to_string(index=False))

    # === Seaborn Theme ===
    sns.set_theme(style="whitegrid", context="talk")

    # --- Plot 1: Approximation Ratio by Family ---
    plt.figure(figsize=(12, 5))
    sns.boxplot(
        x="subfolder", y="ratio", data=df,
        showfliers=False, palette="Set2"
    )
    plt.title("Approximation Ratio (Cmax / T*) by Instance Family")
    plt.xlabel("Instance Family")
    plt.ylabel("Approximation Ratio")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(plots_dir / "ratio_boxplot_by_family.png", dpi=300)
    plt.close()

    # --- Plot 2: Ratio Histogram ---
    plt.figure(figsize=(8, 5))
    sns.histplot(df["ratio"].dropna(), bins=20, kde=True, color="steelblue")
    plt.title("Distribution of Approximation Ratios (Cmax / T*)")
    plt.xlabel("Approximation Ratio")
    plt.ylabel("Number of Instances")
    plt.tight_layout()
    plt.savefig(plots_dir / "ratio_histogram.png", dpi=300)
    plt.close()

    # --- Plot 3: Ratio vs. Number of Jobs (small legend) ---
    plt.figure(figsize=(10, 5))
    sns.scatterplot(
        x="n", y="ratio", hue="subfolder", data=df,
        palette="tab10", alpha=0.7, edgecolor="w", s=50
    )
    plt.title("Approximation Ratio vs. Number of Jobs")
    plt.xlabel("Number of Jobs (n)")
    plt.ylabel("Approximation Ratio")
    plt.legend(
        title="Family", bbox_to_anchor=(1.02, 1), loc="upper left",
        fontsize="small", title_fontsize="small", ncol=1
    )
    plt.tight_layout(rect=[0,0,0.85,1])
    plt.savefig(plots_dir / "ratio_vs_n_scatter.png", dpi=300)
    plt.close()

    # --- Plot 4: Cmax vs. Best Known Objective (legend at bottom) ---
    plt.figure(figsize=(8, 8))
    scatter = sns.scatterplot(
        x="best_objective", y="Cmax", hue="subfolder",
        data=df, palette="tab10", alpha=0.7, edgecolor="w", s=60
    )
    # Diagonal reference line
    all_min = min(df["best_objective"].min(), df["Cmax"].min())
    all_max = max(df["best_objective"].max(), df["Cmax"].max())
    plt.plot([all_min, all_max], [all_min, all_max],
             linestyle="--", color="gray", linewidth=1)

    scatter.set_title("Our Makespan vs. Best Known Solution")
    scatter.set_xlabel("Best Known Makespan")
    scatter.set_ylabel("Our Makespan (Cmax)")

    # Legend placed horizontally below plot
    plt.legend(
        title="Family", loc="upper center",
        bbox_to_anchor=(0.5, -0.10), fontsize="small",
        title_fontsize="small", ncol=2, frameon=False
    )
    plt.tight_layout(rect=[0,0,1,0.95])
    plt.savefig(plots_dir / "cmax_vs_best_objective.png", dpi=300)
    plt.close()

    print("\n✅ Plots saved in:", plots_dir)


if __name__ == "__main__":
    main()
