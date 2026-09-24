$env:OPENBLAS_NUM_THREADS="1"
$env:OMP_NUM_THREADS="1"
$env:MKL_NUM_THREADS="1"
$env:NUMEXPR_NUM_THREADS="1"

cd C:\Zylo\backend
python -m uvicorn server:app --reload --host 0.0.0.0 --port 8000