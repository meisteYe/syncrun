from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from catboost import CatBoostRegressor
import pandas as pd

# Uygulamayı başlat
app = FastAPI(
    title="SyncRun ML API",
    description="SyncRun mobil uygulaması için makine öğrenmesi tahmin servisi.",
    version="1.0.0"
)

# Modeli global olarak yükle (API her istek aldığında modeli baştan yüklemesin diye dışarıda tanımlıyoruz)
try:
    model = CatBoostRegressor()
    model.load_model('syncrun_pace_model.cbm')
    print("✅ CatBoost modeli başarıyla yüklendi.")
except Exception as e:
    print(f"⚠️ Model yüklenirken hata oluştu: {e}")


# Dışarıdan (Flutter'dan) gelecek verinin şemasını (Pydantic ile) tanımlıyoruz
class RunRequest(BaseModel):
    total_distance: float
    day_of_week: int
    hour_of_day: int


# Tahmin yapacak Endpoint (Uç Nokta)
@app.post("/predict_pace/")
def predict_pace(request: RunRequest):
    try:
        # Gelen veriyi modelin anlayacağı Pandas DataFrame formatına çevir
        input_data = pd.DataFrame({
            'totalDistance': [request.total_distance],
            'day_of_week': [request.day_of_week],
            'hour_of_day': [request.hour_of_day]
        })

        # Tahmin yap
        predicted_speed = model.predict(input_data)[0]

        # Hızı (m/s) Pace'e (dk/km) çevir
        if predicted_speed > 0:
            pace_seconds = 1000 / predicted_speed
            pace_minutes = int(pace_seconds // 60)
            pace_sec_rem = int(pace_seconds % 60)
            pace_str = f"{pace_minutes}:{pace_sec_rem:02d}"
        else:
            pace_str = "0:00"

        return {
            "predicted_speed_m_s": round(float(predicted_speed), 2),
            "predicted_pace_per_km": pace_str
        }
    except Exception as e:
        # Hata durumunda mobil uygulamaya düzgün bir HTTP 500 kodu dön
        raise HTTPException(status_code=500, detail=str(e))


# API'nin ayakta olup olmadığını kontrol etmek için basit bir Health Check
@app.get("/")
def health_check():
    return {"status": "SyncRun ML API is running 🏃‍♂️"}