import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# 1. Firebase Admin SDK'yı başlatma
# JSON dosyasının adını tam olarak aşağıya yaz (örneğin: syncrun-firebase-adminsdk.json)
cred = credentials.Certificate("syncrun-firebase-adminsdk.json")
firebase_admin.initialize_app(cred)
db = firestore.client()


def fetch_and_prep_activities():
    print("Firestore'dan veriler çekiliyor...")
    activities_ref = db.collection('activities')
    docs = activities_ref.stream()

    data = []
    for doc in docs:
        doc_data = doc.to_dict()
        doc_data['activity_id'] = doc.id

        # Firestore Timestamp objesini CSV'ye yazarken sorun yaşamamak için siliyoruz
        # Zaten startTime ve endTime bize yetecek
        if 'createdAt' in doc_data:
            del doc_data['createdAt']

        data.append(doc_data)

    df = pd.DataFrame(data)

    if df.empty:
        print("Henüz kaydedilmiş veri yok.")
        return df

    print("Veri çekildi. Feature Engineering (Özellik Çıkarımı) uygulanıyor...")

    # 2. Tarihleri hesaplanabilir formata (DateTime) çevirme
    df['startTime'] = pd.to_datetime(df['startTime'])
    df['endTime'] = pd.to_datetime(df['endTime'])

    # 3. Temel Özellik Çıkarımı
    # Koşu süresi (saniye cinsinden)
    df['duration_seconds'] = (df['endTime'] - df['startTime']).dt.total_seconds()

    # Ortalama Hız (m/s) -> Hedef (Target) değişkenimiz
    df['avg_speed_m_s'] = df['totalDistance'] / df['duration_seconds']

    # Haftanın Günü (0 = Pazartesi, 6 = Pazar)
    df['day_of_week'] = df['startTime'].dt.dayofweek

    # Günün Saati (Sabah koşusu mu, akşam koşusu mu?)
    df['hour_of_day'] = df['startTime'].dt.hour

    return df


if __name__ == "__main__":
    activity_df = fetch_and_prep_activities()

    if not activity_df.empty:
        print("\n--- Çekilen ve İşlenen Veriler ---")
        print(activity_df[['startTime', 'totalDistance', 'duration_seconds', 'avg_speed_m_s', 'day_of_week']])

        # Makine öğrenmesi için CSV'ye aktar
        activity_df.to_csv('syncrun_activities_ml_ready.csv', index=False)
        print("\n✅ Veri seti 'syncrun_activities_ml_ready.csv' olarak kaydedildi.")