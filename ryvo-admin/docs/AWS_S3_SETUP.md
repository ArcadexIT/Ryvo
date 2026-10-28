# AWS S3 setup for RYVO file uploads

RYVO stores provider profile photos, KYC documents, and other uploads in **Amazon S3** using **presigned URLs**:

1. Mobile app calls your API → `POST /provider/files/presign`
2. API returns a short-lived upload URL + permanent `fileUrl`
3. App uploads the file **directly to S3** with `PUT`
4. App saves `fileUrl` in the database via `/provider/documents` or `/provider/profile`

The bucket stays **private**; admins get temporary view links via `/admin/files/access-url`.

---

## Step 1 — Create an S3 bucket

1. Open [AWS Console](https://console.aws.amazon.com/) → **S3** → **Create bucket**
2. **Bucket name**: e.g. `ryvo-uploads-prod` (must be globally unique)
3. **AWS Region**: pick the same region you will use in `.env` (e.g. `ap-southeast-1` for Singapore)
4. **Block Public Access**: keep **all four options ON** (recommended for KYC docs)
5. **Bucket Versioning**: optional (Off is fine to start)
6. **Default encryption**: enable **SSE-S3**
7. Click **Create bucket**

---

## Step 2 — Configure CORS on the bucket

Required so mobile/web clients can `PUT` files to presigned URLs.

1. Open your bucket → **Permissions** → **Cross-origin resource sharing (CORS)**
2. Click **Edit** and paste:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

3. Save changes

> For production, replace `"AllowedOrigins": ["*"]` with your admin URL, e.g. `"http://localhost:3000"`.

---

## Step 3 — Create an IAM user for the API

1. Go to **IAM** → **Users** → **Create user**
2. Name: `ryvo-api-s3`
3. Do **not** enable console access
4. Attach permissions → **Create inline policy** → JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RyvoUploads",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
    }
  ]
}
```

Replace `YOUR-BUCKET-NAME` with your bucket name.

5. Create the user → open the user → **Security credentials** → **Create access key**
6. Choose **Application running outside AWS**
7. Copy **Access key ID** and **Secret access key** (shown once)

---

## Step 4 — Configure the API `.env`

Edit `apps/api/.env`:

```env
AWS_S3_BUCKET="ryvo-uploads-prod"
AWS_REGION="ap-southeast-1"
AWS_ACCESS_KEY_ID="AKIA..."
AWS_SECRET_ACCESS_KEY="your-secret-key"
# Optional — only if you use CloudFront or a custom domain:
# AWS_S3_PUBLIC_BASE_URL="https://cdn.yourdomain.com"
```

Restart the API after saving:

```bash
npm run dev --workspace=@ryvo/api
```

---

## Step 5 — Verify uploads work

### Test presign (provider token required)

```bash
curl -X POST http://localhost:4000/api/v1/provider/files/presign \
  -H "Authorization: Bearer YOUR_PROVIDER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"folder":"documents","filename":"test.jpg","contentType":"image/jpeg"}'
```

You should get:

```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://ryvo-uploads-prod.s3...",
    "fileUrl": "https://ryvo-uploads-prod.s3.ap-southeast-1.amazonaws.com/providers/documents/...",
    "key": "providers/documents/..."
  }
}
```

### Upload a test file to S3

```bash
curl -X PUT "PASTE_uploadUrl_HERE" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/path/to/photo.jpg
```

### Confirm in AWS Console

S3 → your bucket → **Objects** → you should see `providers/documents/...`

---

## Step 6 — Provider app (already wired)

The Flutter provider app uses `FileUploadService`:

- Registration avatar → `providers/avatars/`
- KYC documents → `providers/documents/`

No app changes needed once API `.env` has real AWS credentials.

---

## Folder layout in S3

| Path | Used for |
|------|----------|
| `providers/avatars/` | Provider profile photos |
| `providers/documents/` | KYC (license, vehicle registration, insurance) |
| `customers/` | Customer uploads (future) |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `File storage is not configured` | Replace `AWS_ACCESS_KEY_ID=local` with real keys in `.env` and restart API |
| `403 Forbidden` on PUT | IAM user missing `s3:PutObject` on `arn:aws:s3:::YOUR-BUCKET/*` — attach inline policy (Step 3) |
| `301 PermanentRedirect` | `AWS_REGION` in `.env` does not match bucket region — check bucket region in S3 console |
| Admin cannot preview document | Ensure `POST /admin/files/access-url` works; bucket can stay private |
| CORS error in browser | Update bucket CORS (Step 2) |

---

## Security checklist

- [ ] Bucket public access **blocked**
- [ ] IAM user has **only** `PutObject` + `GetObject` on this bucket
- [ ] Never commit `.env` or access keys to git
- [ ] Rotate access keys periodically
- [ ] Use separate buckets for dev/staging/production
