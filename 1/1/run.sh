for N in 6 7 8;
do
  echo "=== n = $N ==="
  cat <<EOF > tmp.dat
param n := $N;
end;
EOF
  glpsol --model 1.mod --data tmp.dat
done
