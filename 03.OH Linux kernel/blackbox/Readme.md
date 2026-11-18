## blackbox, hievent и `/dev/bbox`

**Кратко:** `/dev/bbox` создаёт драйвер **hievent**, а не blackbox. Имя узла
историческое. В ядре включается параметром `CONFIG_HIEVENT`. При `=y` драйвер встроен в ядро, отдельного .ko в /system/lib/modules не будет

Обе подсистемы — дополнения OpenHarmony к ядру (`drivers/staging/`), в mainline
Linux их нет.

> Для LiteOS (mini/small) есть отдельная библиотека `base/hiviewdfx/blackbox` с той же схемой (`BBoxNotifyError`, `SystemModule*`) — к Linux-ядру отношения не имеет.
