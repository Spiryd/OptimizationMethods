for N in 5 10 15 20
do
  echo "=== n = $N ==="
  cat <<EOF > tmp.dat
param n := $N;
end;
EOF
  glpsol --model hilbert.mod --data tmp.dat
done
