# Дипломный практикум в Yandex.Cloud
# Работу выполнил студент Алкин Т.Г., группа SHDEVOPS-14, Москва 2025 г.

## Цели работы:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:

* Работа выполняется на виртуальной машине  Ubuntu 22.04.5 LTS созданной на рабочей станции Windows 10 Pro в среде Hyper-V.
* Версии ПО: Terraform v1.8.4, Python 3.10.12, kubectl Version: v1.32.3, Docker version 28.0.1, Yandex Cloud CLI 0.152.0,
  git version 2.34.1,  helm Version:v3.17.3, TFLint version 0.58.0

### Создание облачной инфраструктуры

* Создаю KMS ключ и сервисный аккаунт для шифрования бакета и доступа к бакету:

[keys.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/backend/keys.tf)

* Создаю зашифрованный бакет, в котором будет хранится tfstate проекта:

[bucket.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/backend/bucket.tf)

* Поскольку ключи доступа к бакету terraform запрещает передавать в переменных, то мы их экспортируем в рабочее окружение.
* не забываю добавить файл backend.tfvars содержащий секретные ключи в .gitignore
* Файлы tf для создания бекенда помещаем в папку backend отдельную от основного проекта. Делаю это по той причине,
  что backet s3 размером до 1GB входит в free tire и за него не будет списываться оплата. Я могу созданный бекенд
  защитить от удаления и оставить на весь период работы с проектом. Основной же проект может удаляться и создаваться многократно.

[backend](https://github.com/A-Tagir/devops-diplom-yandexcloud/tree/main/backend)

* Применяю:
  
```
yc iam create-token

tiger@VM1:~/Diploma/backend$ terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of yandex-cloud/yandex from the dependency lock file
- Using previously-installed yandex-cloud/yandex v0.145.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

terraform apply -var "token=t1.XXXXX"
```
* Необходимые объекты создались:

![backend_created](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_backend_created.png)

![backend_accounts](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_backend_accounts.png)

* Хочу отметить, что tfstate бекенда храню локально и не буду переносить в бакет, поскольку стейт содержит немного объектов и его потеря не станет критичной.
* Теперь переходим в папку основного проекта main и там конфигурируем backend:

[backend.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/backend.tf)

* Инициализирую:

![main_initialized](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_main_initialized.png)

* Бекенд создан и стейт основного проекта теперь хранится в хранилище s3 облака, зашифрован и защищен от удаления.

* Создаю VPC и подсети: 3 подсети с названием private и 3 подсети с названием public в разных зонах:

[network.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/network.tf)

* Инициализирую:

![main_vpc_init](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_main_vpc_init.png)

* Применяю:

![main_vpc_apply](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_main_vpc_apply.png)

* Удаляю:

![main_vpc_destroy](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_main_vpc_destroy.png)

* Видим, что все работает корректно. Кроме того, видим, что tfstate хранится в облаке и меняется в процессе:

![main_vpc_tfstate](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_main_vpc_tfstate.png)

---
### Создание Kubernetes кластера

* K8s кластер буду развертывать самостоятельно, с помощью  kubespray. У меня есть опыт развертывания с помощью kubespray из заданий курса, воспользуюсь им.
  Для экономии ресурсов разверну один мастер в зоне ru-central1-a и две вокер-ноды в зонах ru-central1-a и ru-central1-b.

* Для этого подготовлю 3 виртуальные машины. В процессе использую циклы, которые изучали в блоке про терраформ. Для удобства,
  все что касается развертывания машин поместил в файл k8s.tf, в том числе и outputs. Кроме того, в файле cloud-init.yml
  указал установку ПО, которое будет нужно при развертывании и диагностики кластера с kubespray.
  Выбран, уже привычный для меня Ubuntu 22.04.5, core fraction 20, RAM 4, CPU 2, HDD 20. С такими параметрами не возникало трудностей
  в предыдущих заданиях. Правила безопасности, пока, разрешено все. Позднее сделаю тонкую настройку.

[k8s.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/k8s.tf)

[cloud-init.yml](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/cloud-init.yml)

[variables.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/variables.tf)

* Проверяю tflint, применяю: terraform apply -var "token=XXX"

![nodes have been applied](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_nodes_apply.png)

* Далее добавляем настройки автоматического выполнения всех операций через terraform в k8s.tf.
  - установку пакетов переносим из cloud-init в модуль provisioner "remote-exec". Связано это с тем, что важна последовательность команд.
  - в модуле provisioner "remote-exec" также добавляем публичный IP мастер-ноды в сертификат, чтобы я мог со своей машины к ней подключиться.
  - применяется модуль resource "null_resource" с depends, когда необходимо ждать, чтобы другие ресурсы были созданы, операции выполнены и известны результаты (например, ip адрес).
  - Так же, копируем на удаленной машине cp /etc/kubernetes/admin.conf /tmp/admin.conf, а затем копируем на мою локальную машину, не забыв удалить из tmp директории.
  - После завершения работы terraform, остается только скопировать полученный файл admin.conf в папку .kube и заменить 127.0.0.1 на публичный IP мастер-ноды.
  - В networks.tf удаляю неиспользуемые сети.
  
* Плюсы данной схемы установки:
  - Все выполняется автоматически, ручных операций нет.
  - Идемпотентность
* Минусы
  - Долгое выполнение (около 25 минут) и, соответственно, долгая отладка.
  - приватный ключ передается на мастер-ноду.
  - пока в правилах security-group "разрешено все".
* Итоговый код здесь:

[project](https://github.com/A-Tagir/devops-diplom-yandexcloud/tree/main/main)

* Применяем:

![cluster_creating](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_cluster_creating.png)

* Кусок с результатами выполнения ansible-playbook:

![cluster_kubespray](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_cluster_kubespray.png)

* Выполнение завершено:

![cluster_been_created](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_cluster_been_created.png)

* Проверяем работу кластера:

![k8s_cluster_OK](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_cluster_OK.png)

* Видим, что ноды работают, служебные pod-ы запущены и без ошибок.

* Теперь отлаживаю безопасность в security group:
  - Разрешаем только трафик внутри группы, а также с моей workstation (IP добавлен в personal.auto.tfvars).
  - Кроме того, в kubespray inventory указываем приватные IP адреса машин, а не публичные.
```

ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24", var.my_ip ]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24", var.my_ip ]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

```
* Пересоздаю кластер, проверяю - все работает.
* Удаляю проект для экономии ресурсов гранта, поскольку его легко создать заново для продолжения работы.
---

### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

### Деплой инфраструктуры в terraform pipeline

1. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ на 80 порту к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ на 80 порту к тестовому приложению.
5. Atlantis или terraform cloud или ci/cd-terraform
---
### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---

