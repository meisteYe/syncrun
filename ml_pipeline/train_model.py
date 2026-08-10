import pandas as pd
from catboost import CatBoostRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, mean_squared_error
import numpy as np


def train_pace_model():
    print("Veri seti yükleniyor...")
    try:
        df = pd.read_csv('syncrun_activities_ml_ready.csv')
    except FileNotFoundError:
        print("Hata: CSV dosyası bulunamadı. Önce data_pipeline.py dosyasını çalıştırın.")
        return

    if len(df) < 3:
        print("Modeli eğitmek için veri çok yetersiz. En az 3 antrenman kaydı gerekiyor.")
        return

    # Hedef Değişken (Tahmin etmeye çalıştığımız şey: Ortalama Hız - m/s)
    y = df['avg_speed_m_s']

    # Özellikler (Modelin öğrenirken bakacağı ipuçları)
    # Şimdilik: Toplam mesafe, haftanın günü ve günün saati
    X = df[['totalDistance', 'day_of_week', 'hour_of_day']]

    # Veriyi eğitim ve test olarak ikiye ayırma
    # Veri seti şu an çok küçük olduğu için test_size'ı çok düşük tutuyoruz
    test_size = 0.2 if len(df) > 10 else 1

    # Sadece 3 satırımız olduğu için şimdilik train_test_split yerine tüm veriyi kullanacağız (MVP aşaması)
    if len(df) < 5:
        print("Veri seti 5 satırdan az olduğu için tüm veri eğitim için kullanılıyor (Test ayrılmadı).")
        X_train, y_train = X, y
        X_test, y_test = X, y
    else:
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=42)

    print("\nCatBoost Modeli Eğitiliyor...")
    # CatBoost Regressor (Sürekli bir sayı tahmin edeceğimiz için Regressor kullanıyoruz)
    model = CatBoostRegressor(
        iterations=100,  # Öğrenme döngüsü sayısı (Veri arttıkça 500-1000 yapılabilir)
        learning_rate=0.1,  # Öğrenme katsayısı
        depth=4,  # Ağaç derinliği
        loss_function='RMSE',
        verbose=10  # Her 10 adımda bir log bas
    )

    # Modeli Eğit
    model.fit(X_train, y_train, cat_features=['day_of_week'])

    # Test verisi üzerinde tahmin yap ve başarıyı ölç
    predictions = model.predict(X_test)

    mae = mean_absolute_error(y_test, predictions)
    rmse = np.sqrt(mean_squared_error(y_test, predictions))

    print("\n--- Model Performansı ---")
    print(f"Mean Absolute Error (MAE): {mae:.4f} m/s")
    print(f"Root Mean Squared Error (RMSE): {rmse:.4f} m/s")

    # Özellik Önem Dereceleri (Feature Importance)
    # Hangi faktörün hızını daha çok etkilediğini gösterir
    feature_importances = model.get_feature_importance()
    print("\n--- Özelliklerin Etkisi (Feature Importance) ---")
    for score, name in zip(feature_importances, X.columns):
        print(f"{name}: {score:.2f}%")

    # Modeli Kaydet (İleride API ile canlı olarak kullanmak için)
    model.save_model('syncrun_pace_model.cbm')
    print("\n✅ Model başarıyla 'syncrun_pace_model.cbm' olarak kaydedildi.")

    # --- ÖRNEK TAHMİN (Senaryo) ---
    print("\n🔮 Gelecek Antrenman Tahmini:")
    print("Senaryo: Bu Cuma (Gündüz 18:00), 5000 metre (5km) koşarsam tahmini hızım ne olur?")

    # Cuma = 4 (Pzt=0), Saat = 18, Mesafe = 5000
    sample_run = pd.DataFrame({
        'totalDistance': [5000],
        'day_of_week': [4],
        'hour_of_day': [18]
    })

    predicted_speed = model.predict(sample_run)[0]
    # Dakika/Kilometre (Pace) formatına çevirme
    if predicted_speed > 0:
        pace_seconds = 1000 / predicted_speed
        pace_minutes = int(pace_seconds // 60)
        pace_sec_rem = int(pace_seconds % 60)
        print(f"Tahmini Ortalama Hız: {predicted_speed:.2f} m/s")
        print(f"Tahmini Tempo (Pace): {pace_minutes}:{pace_sec_rem:02d} dk/km")
    else:
        print("Model henüz mantıklı tahminler yapacak kadar öğrenemedi.")


if __name__ == "__main__":
    train_pace_model()