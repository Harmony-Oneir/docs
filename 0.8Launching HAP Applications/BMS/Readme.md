# Bundle Manager Service
BMS (Bundle Manager Service, подсистема bundlemanager, компонент bundle_framework) — системная служба OpenHarmony, которая управляет пакетами приложений. Она устанавливает, обновляет и удаляет HAP/HSP. При установке разбирает module.json и проверяет подписи и профили. Она хранит базу установленных бандлов: bundleName, ability, extension, разрешения, uid/gid. На этот реестр опираются AbilityManager, AppMgr, AccessToken и launcher. Работает в процессе foundation как SA 401 (libbms.z.so). Привилегированные файловые операции (каталоги /data/app/el*, распаковка, .so, права) вынесены в отдельный демон installs (SA 511). При первом запуске BMS сканирует предустановленные приложения из /system/app и /preload и регистрирует их. Утилита bm (bm install/dump/uninstall) обращается именно к нему.


## Функции Bundle Framework (специфика BMS)

| Аргумент | По умолч. | Что включает |
|---|---:|---|
| `bundle_framework_graphics` | `true` | Поддержка иконок приложений через `image_framework`; NDK drawable API; `bundlemgr_graphics inner_api` |
| `bundle_framework_free_install` | `true` | Атомарные сервисы / свободная установка. Требует: `ability_runtime`, `account`, `power`, `usage_stats` |
| `bundle_framework_default_app` | `true` | Управление приложением по умолчанию (`DefaultApp`) |
| `bundle_framework_launcher` | `true` | Launcher API — получение приложений для рабочего стола |
| `bundle_framework_sandbox_app` | `true` | Sandbox-приложения — изолированные окружения |
| `bundle_framework_quick_fix` | `true` | Hot patch / QuickFix — точечные патчи без переустановки |
| `bundle_framework_app_control` | `true` | AppControl — блокировка и управление запуском приложений |
| `bundle_framework_overlay_install` | `true` | Overlay-пакеты — наложение ресурсов поверх базового приложения |
| `bundle_framework_bundle_resource` | `true` | BundleResource — динамические ресурсы иконок и лейблов. Требует `global_resmgr` |
| `bundle_framework_power_mgr_enable` | `true` | Интеграция с Power/Battery/Display Manager |
| `bundle_framework_form_dimension_2_3` | `false` | Виджеты формата 2×3 |
| `bundle_framework_form_dimension_3_3` | `false` | Виджеты формата 3×3 |
| `bundle_framework_bss_enable` | `false` | BSS (Bundle Sharing Service) — общие библиотеки между приложениями |
| `bundle_framework_npapi_enable` | `false` | NPAPI-плагины |
| `bundle_framework_app_fwk_update_enable` | `true` | Обновление app-framework через WebView. Требует `webview_enable` |
| `bundle_framework_enable_clone_for_account` | `false` | Клонирование приложений для разных аккаунтов |
| `distributed_bundle_framework` | `true` | Распределённый BMS — работа с пакетами на удалённых устройствах |

## Зависимые подсистемы (внешние компоненты)

| Аргумент | По умолч. | Что включает |
|---|---:|---|
| `ability_runtime_enable` | `true` | Интеграция с Ability Runtime |
| `account_enable` | `true` | Поддержка мультиаккаунтов (`os_account`) |
| `configpolicy_enable` | `true` | Политики конфигурации устройства |
| `global_resmgr_enable` | `true` | Resource Manager — мультиязычные ресурсы |
| `global_i18n_enable` | `true` | i18n / локализация |
| `hicollie_enable` | `true` | HiCollie — watchdog для зависших потоков |
| `hisysevent_enable` | `true` | HiSysEvent — системные события и аудит |
| `storage_service_enable` | `true` | Файловое хранилище (`storage_service`) |
| `window_enable` | `true` | Window Manager — оконная система |
| `dlp_permission_enable` | `true` | DLP — защита данных от утечки |
| `code_signature_enable` | `true` | Проверка подписи кода |
| `code_encryption_enable` | `true` | Шифрование кода (`crypto_metadata`) |
| `verify_abc_enabled` | `true` | Верификация ABC-файлов (байткод ArkCompiler) |
| `check_eldir_enabled` | `true` | Проверка EL-директорий (уровни шифрования) |
| `udmf_enabled` | `true` | UDMF — унифицированное управление данными |
| `bms_device_info_manager_part_enabled` | `true` | Device Info Manager |
| `app_domain_verify_enabled` | `true` | Верификация доменов приложений |
| `device_usage_statistics_enabled` | `true` | Статистика использования устройства |
| `dfx_sigdump_handler_enabled` | `true` | DFX — обработчик сигналов и дампов |
| `webview_enable` | `true` | WebView-движок |
| `user_auth_framework_impl_enabled` | `true` | Аутентификация пользователей (биометрия и т. д.) |
| `api_metrics_enable` | `true` | Метрики вызовов API |
| `bms_accesscontrol_sandbox_manager` | `false` | Sandbox Manager для контроля доступа (auto-detect) |
| `use_pre_bundle_profile` | `true` | Использование предустановленного профиля пакетов |
