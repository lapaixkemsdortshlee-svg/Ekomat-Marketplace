# AyitiMarket - Guide de Déploiement Mobile

> Source : `AyitiMarketDeploymentGuide.pdf` (fourni par Thrasher). Converti en
> markdown pour vivre dans le repo (cherchable, versionné).
>
> **Vèsyon** 2.0.0 - MVP Final · **Stack** HTML/Tailwind/JS + Supabase BaaS ·
> **Wrapper** Capacitor 6.x (Ionic) · **Hosting** Vercel (auto-deploy via GitHub) ·
> **Dat** Avril 2026
>
> Chemin : PWA → Android (APK) → Google Play Store · PWA → iOS (IPA) → Apple App Store

## Kontni
1. Achitekti Pwojè a
2. Prè-rekwi (Prerequisites)
3. Konfigirasyon Environman
4. Capacitor - Inisyalizasyon
5. Build Android (APK/AAB)
6. Build iOS (IPA)
7. Manifest PWA & Service Worker
8. Vercel - Deployment Otomatik
9. Supabase - Konfigirasyon Pwodiksyon
10. Checklist Avan Soumisyon Store

## 1. Achitekti Pwojè a
AyitiMarket se yon PWA (Progressive Web App) ki fonksyone nan navigatè men ki ka transfòme an app natif pou Android ak iOS atravè Capacitor.

```
ayitimarket/
  index.html          # App konplè (HTML+CSS+JS)
  vercel.json         # Config Vercel
  manifest.json       # PWA manifest
  sw.js               # Service Worker (offline)
  capacitor.config.ts # Config Capacitor
  package.json
  android/            # Pwojè Android Studio
  ios/                # Pwojè Xcode
```

## 2. Prè-rekwi
- Node.js v18+ ak npm
- Android Studio (pou Android build) + JDK 17
- Xcode 15+ (pou iOS - sèlman sou macOS)
- Capacitor CLI : `npm install -g @capacitor/cli`
- Git ak GitHub account
- Vercel account konekte ak GitHub repo
- Supabase account ak pwojè aktif
- Google Play Console ($25 yon sèl fwa)
- Apple Developer Program ($99/an)

## 3. Konfigirasyon Environman
Kreye dosye pwojè a epi inisyalize npm :
```
mkdir ayitimarket && cd ayitimarket
npm init -y
npm install @capacitor/core @capacitor/cli
```
Kopye `index.html`, `manifest.json`, `sw.js` nan rasin dosye a.

## 4. Capacitor - Inisyalizasyon
```
npx cap init AyitiMarket com.ayitidigital.ayitimarket --web-dir=.
```
`capacitor.config.ts` :
```ts
import { CapacitorConfig } from '@capacitor/cli';
const config: CapacitorConfig = {
  appId: 'com.ayitidigital.ayitimarket',
  appName: 'AyitiMarket',
  webDir: '.',
  server: {
    androidScheme: 'https',
    iosScheme: 'https',
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: false,
      backgroundColor: '#fcf9f4',
    },
  },
};
export default config;
```
Ajoute platfòm yo :
```
npx cap add android
npx cap add ios
```

## 5. Build Android (APK / AAB)
1. Sinkronize kòd web la : `npx cap sync android`
2. Ouvri nan Android Studio : `npx cap open android`
3. Konfigure Signing : Build → Generate Signed Bundle/APK → kreye yon nouvo keystore (`.jks`). **Konsève keystore la nan yon kote ki an sekirite** - ou pap ka mete app la ajou san li.
4. Build Release : chwazi Android App Bundle (`.aab`) pou Google Play. Build → Generate Signed Bundle → release. Fichye a : `android/app/build/outputs/bundle/release/app-release.aab`
5. Upload sou Google Play Console :
   - Ale sou play.google.com/console
   - Kreye nouvo app : AyitiMarket
   - Ranpli tout enfòmasyon (deskripsyon, screenshot, ikòn 512x512)
   - Upload `.aab` nan Production → Create Release
   - Soumèt pou Review (3-7 jou)

## 6. Build iOS (IPA)
Rekwi macOS ak Xcode 15+.
1. Sinkronize : `npx cap sync ios`
2. Ouvri Xcode : `npx cap open ios`
3. Konfigure Signing : Signing & Capabilities → chwazi Team (Apple Developer account) → Bundle ID : `com.ayitidigital.ayitimarket`
4. Archive ak Upload :
   - Product → Archive
   - Distribute App → App Store Connect → Upload
   - Ale sou appstoreconnect.apple.com
   - Kreye app, ranpli metadata, screenshot
   - Soumèt pou Review (1-3 jou)

## 7. Manifest PWA & Service Worker
`manifest.json` :
```json
{
  "name": "AyitiMarket",
  "short_name": "AyitiMarket",
  "description": "Marketplace mobile pou Ayiti",
  "start_url": "/index.html",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#fcf9f4",
  "theme_color": "#00666f",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```
`sw.js` (Service Worker - Offline Cache) :
```js
const CACHE = 'aym-v2';
const URLS = ['/', '/index.html'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(URLS)));
});
self.addEventListener('fetch', e => {
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request))
  );
});
```

## 8. Vercel - Deployment Otomatik
Repo GitHub `ayitimarket` deja konekte ak Vercel. Chak push sou branch `main` deklanche yon deploy otomatik.

Workflow pou mete ajou :
1. Modifye `index.html` lokalman oswa sou github.com
2. `git add . && git commit -m 'update' && git push`
3. Vercel detekte push la epi deploy otomatikman (30-60s)
4. Verifye sou URL Vercel ou a

## 9. Supabase - Konfigirasyon Pwodiksyon
- **Site URL** : mete URL Vercel ou nan Authentication → URL Configuration
- **Redirect URLs** : ajoute URL Vercel + localhost pou devlopman
- **Google OAuth** : verifye Client ID nan Providers → Google
- **RLS Policies** : egzekite les migrations nan SQL Editor
- **Storage Buckets** : kreye `avatars` ak `products` (piblik)
- **Plan Blaze** : upgrade pou Edge Functions si nesesè

## 10. Checklist Avan Soumisyon Store
| Item | Detay |
|------|-------|
| Ikòn App | 512x512 PNG, fon teal #00666f ak logo blan |
| Screenshot | Omwen 4 screenshot telefòn (1080x1920) |
| Deskripsyon | Kreyòl + Fransè, 80 karaktè max pou titre |
| Kategori | Shopping / Marketplace |
| Privacy Policy | Mete yon paj privacy policy sou sit la |
| Age Rating | Everyone / 4+ |
| Tès | Teste sou 3+ aparèy avan soumisyon |
| Performance | Lighthouse score > 80 pou PWA |
| Supabase RLS | Tout tab gen Row Level Security aktive |
| HTTPS | Vercel bay HTTPS otomatikman |
| Offline | Service Worker cache paj prensipal yo |
| Deep Links | Konfigure pou Google OAuth callback |

---
*AyitiMarket - Ayiti Digital © 2026 · Marketplace mobile pou mache ayisyen an*
