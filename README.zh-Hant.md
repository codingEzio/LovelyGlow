<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

選用 Pixel 字型使用 DeparturePixelZh Compact 0.1.1，儲存庫不含字型。打包前執行 `python3 script/get_compact_font.py` 下載並校驗固定版本。聲明與範圍見[相依說明](DEPENDENCIES.md)。 如需本機字型，建置時將 `LOVELYGLOW_PRIVATE_FONT` 設為字型檔路徑。請將字型保存在儲存庫外或被忽略的 `Local/` 中；打包前會驗證字型，可將 `LOVELYGLOW_PRIVATE_FONT_NOTICES` 設為對應聲明目錄；未提供時，套件會標明沒有提供聲明。

macOS 原生選單列工具，為目前作用中視窗繪製一圈邊光。它不調暗內容、不排列視窗，也不接管其他 App 的視窗。

## 使用與行為

啟用 Glow 後跟隨前景 App 的目前視窗。小型無標題輔助視窗預設排除，可在 More 中明確開啟。彈出自己的選單、Cmd+Tab 或 Spotlight 時保留原視窗；全螢幕、Mission Control 與填滿工作區的視窗會隱藏邊光。邊光不接收點擊，也不搶鍵盤焦點。

選單列彈出面板可直接調整色彩、尺寸、動態、出現方式與字型。System 是預設字型，隨附 Pixel Compact 可選並儲存。Instant 與 Seamless 共用一個覆蓋視窗；更新跟隨目前螢幕節奏。核心測試不證明實際手勢、螢幕流暢度或像素對齊。Stage Manager、自訂視窗形狀與未來 macOS 的空間偵測仍有限制。

## 原始碼建置

需要 Apple Silicon、macOS 27+，以及選定的相容 Xcode／Swift 6.2+ SDK。沒有下載的 Swift 套件，也不依賴相鄰儲存庫。先完成 Apple 官方的 Xcode 安裝與授權確認。

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
python3 -m unittest discover -s script -p test_migrate_settings.py
```

`just` 只提供既有指令捷徑；等效核心測試是 `swift test --jobs 2 --scratch-path Local/swift-test`。測試使用合成資料，不啟動 App、不要求輔助使用權限，也不安裝或變更登入項目。`SWIFT_JOBS` 預設 2；`SWIFT_SCRATCH_PATH` 預設 `Local/swift-test`。無效參數明確失敗。

### 執行開發版

在儲存庫執行 `./script/dev.sh --run`，不需簽署憑證即可建置臨時簽署的 App 並在終端機執行；按 Control-C 或使用 App 的結束命令停止。`./script/dev.sh --build` 只建置並輸出路徑；`just dev` 和 `just dev-build` 等效。每次建置會新建 `Local/lovelyglow-dev.*` 目錄，並重用 `Local/swift-dev-build` SwiftPM 快取。停止 App 後可手動刪除不再需要的套件目錄；沒有建置執行時可刪除快取以釋放空間。失敗的建置目錄也會保留。

開發版使用獨立身分 `com.github.codingEzio.LovelyGlow.Development` 和設定 `~/Library/Application Support/com.github.codingEzio.LovelyGlow.Development/config.toml`。設定會在開發執行之間保留；僅在需要捨棄時手動刪除該目錄。使用權限控制主動要求輔助使用權限；啟動時不會要求。如開啟登入啟動，刪除 App 前先在開發版關閉。清理後 macOS 可能保留權限記錄。選用字型僅在下載或自行提供並校驗後隨包提供；沒有字型時可使用系統字型。此流程不會安裝或替換正式簽署產品。

## 簽署安裝與權限

本機簽署設定 `config/product.conf` 優先；沒有時使用保留相同產品身分、沒有簽署身分的 `config/product.public.conf`。此儲存庫不含私人設定。編譯成功不等於已有可執行的簽署 App。

```sh
just stage
just install
```

這些指令需要你設定的本機憑證與簽署身分。Stage 建立獨立候選，不停止日用 App；Install 核對簽章要求，才替換並啟動 `~/Applications/LovelyGlow.app`。不會改用臨時簽章或新 bundle ID 繞過檢查。打包使用原生 iconutil／sips、選用 rsvg-convert 與 Python 圖示備援路徑。

使用權限控制主動要求輔助使用權限；啟動時不會要求。沒有權限時，一般切換仍可使用視窗系統邊界，但拖曳跟隨較弱。登入啟動只由使用者明確開啟的 SMAppService 管理；沒有 HTTP 服務、LaunchAgent 或 Process Compose。

## 資料與移轉

0.7.9／33 起唯一活動設定為 `~/Library/Application Support/com.alex.LovelyGlow/config.toml`，不將執行設定寫回程式碼目錄。安裝器從舊簽署 App 的中繼資料讀取原路徑，在停止舊程序後逐位元組複製並讀回。目標已有不同內容時中止，不覆寫任一檔案；舊檔保留供復原。新安裝直接使用 Application Support。建置輸出留在忽略的 Local／dist，與使用者設定分開。

## 授權與來源審閱

README 圖示是 codingEzio 創作的獨立文件 SVG，採用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。此授權不改變產品圖示、字型或第三方權利。

自有軟體採 [MIT](LICENSE)。選用字型保留[完整 OFL 與元件聲明](Resources/Licenses/NOTICE.md)。[LICENSE-SCOPE.md](LICENSE-SCOPE.md) 區分軟體、字型與圖稿。此儲存庫排除權利未證的原始圖示，使用明確列名的原創 CC BY 4.0 幾何佔位圖；私人打包仍保留原圖，不代表可公開它。

來源歷史及驗證範圍見 [PUBLICATION.md](PUBLICATION.md)。
