# Контейнер для сборки

Для сборки проекта будет использоваться Docker контейнер. Этот контейнер будет использоваться на протяжении всех этапов сборки. Для сборки контейнера используйте следующую команду:

```bash
docker build -t openharmony:3.2 \
  --build-context mesa=/mnt/ohos/OpenHarmont7/third_party/mesa3d \
  -f Dockerfile .
```
После сборки образа запуск следующей командой:

```bash
# если старый контейнер с этим именем ещё есть — удалить (данные на хосте не затрагиваются)
docker rm -f ohos-build

docker run -it \
  --name ohos-build \
  -v /mnt/ohos/OpenHarmony7:/home/openharmony \
  -w /home/openharmony \
  openharmony:3.2
```

Вернуться в контейнер:

```
docker start ohos-build
docker exec -it ohos-build /bin/bash
```

Внутри контейнера необходимо установить инструменты необходимые для сборки:

```
bash build/prebuilts_download.sh
```

# Подготовка описаний продуктов

Перед сборкой положите описания продуктов из [common/products/oneir.json](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/) в каталог `productdefine/common/products/`. Значение из `product_name` используется в следующей команде:
```
./build.sh --product-name <name> --no-prebuilt-sdk --skip-partlist-check --build-only-load
```
Имя продукта нужно добавить в белый список сборки в файле `build/subsystem_components_whitelist.json`:

```
{
[...]
  "product_oneir": "product_oneir",
[...]
}
```
