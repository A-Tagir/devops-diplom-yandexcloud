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

* Рабочая среда организована на виртуальной машине  Ubuntu 22.04.5 LTS созданной на рабочей станции Windows 10 Pro в среде Hyper-V.
* Проект выполняется в Yandex Cloud.
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
  - После завершения работы terraform, остается только скопировать полученный файл cube_config в папку .kube и заменить 127.0.0.1 на публичный IP мастер-ноды.
  - В networks.tf удаляю неиспользуемые сети.
  
* Плюсы данной схемы установки:
  - Все выполняется автоматически, ручных операций нет.
  - Идемпотентность
* Минусы
  - Долгое выполнение (около 25 минут) и, соответственно, долгая отладка.
  - приватный ключ передается на мастер-ноду.
  - пока в правилах security-group "разрешено все".
* Итоговый код здесь:

[project](https://github.com/netology-code/devops-diplom-yandexcloud/tree/64bae9d9152a4130f38466c800c521d4f57e117d)

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

* Создаю приложение, которое выдает статическую страницу, создаю Deploy и service типа NodePort для доступа к приложению из сети интернет

[devops-diplom-application](https://github.com/A-Tagir/devops-diplom-application)

* Собираю приложение и логинюсь в dockerhub:

![AppDockerHubLogin](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppDockerHubLogin.png)

* Отправляю собранный образ в dockerhub:

![AppDockerHubPushed.](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppDockerHubPushed.png)

* Проверяю, что образ появился:

![AppDockerHubImage](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppDockerHubImage.png)

* Пробуем продеплоить приложение в кластер, чтобы убедиться, что он рабочий:

![AppDockerContainerCreating](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppDockerContainerCreating.png)

* Пробуем посмотреть логи контейнера:

```
tiger@VM1:~/Diploma/main$ kubectl logs devcats-deployment-7d5f67f4b-p7vrl
Error from server: Get "https://10.0.20.19:10250/containerLogs/default/devcats-deployment-7d5f67f4b-p7vrl/devcats":
dial tcp 10.0.20.19:10250: i/o timeout
```

* Модифицируем security group для разрешения всего трафика внутри кластера, а также, к порту TCP 30001 с моей рабочей станции:

```
resource "yandex_vpc_security_group" "k8s" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.cloud-netology.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24", var.my_ip ]
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24" ]
  }

  ingress {
    protocol       = "TCP"
    port           = 30001
    v4_cidr_blocks = [ var.my_ip ]
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
}

```

* Применяем:

![AppSecurityGroupModified](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppSecurityGroupModified.png)

* Проверяем логи и видим, что кластер теперь работает корректно:

![AppK8Slogs](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppK8Slogs.png)

* Применяем сервис типа NodePort:

```
tiger@VM1:~/DiplomaApp$ kubectl apply -f devcats-service.yaml
service/netology-devcats created
tiger@VM1:~/DiplomaApp$ kubectl get svc
NAME               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
kubernetes         ClusterIP   10.233.0.1    <none>        443/TCP        33m
netology-devcats   NodePort    10.233.1.22   <none>        80:30001/TCP   3s
tiger@VM1:~/DiplomaApp$
```
* Проверяем доступ:

![k8s_AppOk](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_AppOk.png)

* На этом считаем, что кластер работает корректно и приложение создано. Приступаем к следующему этапу.

---
### Подготовка cистемы мониторинга и деплой приложения

* Выбираю установку системы мониторинга через helm-chart. Готовлю базовый манифест:

[monitoring_values.yaml](https://github.com/A-Tagir/devops-diplom-application/blob/main/monitoring_values.yaml)

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f monitoring_values.yaml
```
* Устанавливаю:

![MonitoringInstalledWithHelm](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_MonitoringInstalledWithHelm.png)

* Подключаюсь

![MonitoringGrafanaLogin](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_MonitoringGrafanaLogin.png)

* Видим, что Дашборды, которые я добавил в конфиге есть:

![MonitoringDashboards](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_MonitoringDashboards.png)

* Метрики нод отображаются:

![NodesMetrics](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_MonitoringDashboard.png)

* Мониторинг установлен, приложение задеплоено.

### Деплой инфраструктуры в terraform pipeline

* Поскольку я на первом этапе не настроил автоматический деплой конфигурации терраформ, то буду делать это сейчас.
* Первоначальный вариант был рассчитан на локальный запуск, поэтому пришлось сделать изменения для возможности запуска через Github workflow.
  - был добавлен terraform.tfvars, куда я вынес нечувствительные переменные. А оставшиеся секреты из personal.auto.tfvars были добавлены 
    в github secrets and variables. Также, добавлен статический ключ: yc iam access-key create --service-account-name  bucket-encrypt-account,
    который в локальной версии не был необходим (для подключения к бекенд).
    ![TFpipline_secrets](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_secrets.png)

* Был также доработан основной k8s.tf 
  - изменен provisioner "local-exec" в котором прямые ссылки на admin.conf заменены на относительные, а также добавлено копирование 
    admin.conf в github artifacts.
  - Доступ к порту 22 SSH был разрешен для public интернет, поскольку необходим доступ с серверов github workflow.
  - Также изменена работа с public/private key:
```
locals {
     ssh_key = fileexists("~/.ssh/tagir.pub") ? file("~/.ssh/tagir.pub") : var.ssh_public_key
     ssh_private_key = fileexists("~/.ssh/id_rsa") ? file("~/.ssh/id_rsa") : var.ssh_private_key
     subnet_map = {
    "public1" = yandex_vpc_subnet.public1.id
    "public2" = yandex_vpc_subnet.public2.id
  }
}
```
* конечная версия проекта может работать корректно как локально, так и через github workflow.

* Создал github workflow:

[terraform-deployment.yml](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/.github/workflows/terraform-deployment.yml) 

* workflow включает следующие этапы:
  - инициализация
  - валидация и проверка форматирования
  - создание плана
  - применение для автоматического запуска
  - применение для ручного запуска
  - копирование kubeconfig во временную папку
  - загрузку kubeconfig в github artifacts
  - удаление проекта

* Делаю commit в main и проверяю:

![k8s_TFpipline_commit](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_commit_k8s.png)

![workflow_started](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_workflow_started_k8s.png)

* Видим, что все запустилось и ждем окончания процесса:

![workflow_succeed](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_workflow_succeed_k8s.png)

![workflow_full](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_workflow_full_k8s.png)

* Копирую kubeconfig из artefacts в локальный ./kube/config (заменив 127.0.0.1 на public ip мастера) и проверяю:

![workflow_kubectl](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_workflow_kubectl_k8s.png)

* Кластер создался и работает.
* Внесем изменения в k8s.tf: disk_volume   = 20 > disk_volume   = 30
* Пушим и проверяем:

![workflow_disk_volume](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_workflow_disk_volume_k8s.png)
* Вижу, что это было прохой идеей - параметр disk_volume является unmutable и без пересоздания инстанса не меняется. Поскольку у меня не 
  указан lifecycle {  ignore_changes = [boot_disk[0].initialize_params[0].image_id]  } то workflow начал пересоздавать кластер полностью.
  Добавлю этот параметр, для предотвращения пересоздания нод, поскольку операция очень длительная.

* Видим, что workflow создан и работает корректно.
* Теперь нужно выполнить требования "Http доступ на 80 порту к web интерфейсу grafana" и "Http доступ на 80 порту к тестовому приложению".
* Это можно сделать создав yandex applicaton balancer. Он будет перенаправлять запросы напрямую в группу приложения
  или в группу графаны, если указан путь /monitor
* Создаю конфигурацию для балансер:

[balancer.tf](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/main/balancer.tf)

* Также в k8s.tf добавлены правила группы безопасности, разрешающие доступ для адресов yandex health-check.
* Кроме того в настройках графаны добавляем правила, которые позволяют работать через префикс /monitor :
```
 grafana.ini:
    server:
      domain: ""
      root_url: "http:///monitor"
      serve_from_sub_path: true
```
* Применяем конфигурацию:

![balancer_created](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_balancer_created.png)

* забыл добавить output для IP балансер, пушаем и смотрим (применяется автоматом):

![balancer_ip_output](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_balancer_ip_output.png)

* Смотрим в консоли яндекс:

![balancer_console](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_balancer_console.png)

* Теперь проверяем работу:

![balancer_web](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_balancer_web.png)

![balancer_monitor](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_TFpipline_balancer_monitor.png)

* Как видим, все работает.
* Добавил небольшой скрипт, который запускаю после окончания работы Workflow, чтобы запустить приложение и монитринг:

[apply.sh](https://github.com/A-Tagir/devops-diplom-application/blob/main/apply.sh)

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes: [main](https://github.com/A-Tagir/devops-diplom-yandexcloud/tree/main/main)
2. Http доступ на 80 порту к web интерфейсу grafana. - Есть
3. Дашборды в grafana отображающие состояние Kubernetes кластера - Есть
4. Http доступ на 80 порту к тестовому приложению - Есть
5. Atlantis или terraform cloud или ci/cd-terraform - Github Workflow.
---

### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

* Буду использовать GitHub Workflow, поскольку он уже используеся для terraform pipeline.
* Создаю новый workflow:

[image-deploy.yml](https://github.com/A-Tagir/devops-diplom-application/blob/main/.github/workflows/image-deploy.yml)

* Здесь, при добавлении kube_config в GitHub secrets необходимо закодировать конифгурация в base64:
```
tiger@VM1:~/.kube$ base64 -w 0 ~/.kube/config
```
* создаем отдельный token для доступа в dockerhub и также добавляем в в GitHub secrets.
* Workflow состоит из следующих этапов:
  - авторизация в докерхаб
  - сборка образа и загрузка в докерхаб
  - создание среды для запуска kubectl
  - деплой собранного образа в кластер
  - проверка состояния деплоя
* Проверяем. Правим текст в файле index.html: "Cats save the world version 1.1" на "Cats save the world version 1.2"
* Пушим в git
```
tiger@VM1:~/DiplomaApp/data$ git commit index.html -m 'version 1.2'
[main 15bc591] version 1.2
 1 file changed, 1 insertion(+), 1 deletion(-)
tiger@VM1:~/DiplomaApp/data$ git push origin main
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 4 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 386 bytes | 386.00 KiB/s, done.
Total 4 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To https://github.com/A-Tagir/devops-diplom-application.git
   6ac460a..15bc591  main -> main
```
* Смотрим в workflow. Видим, что все выполнилось, появились новые реплики приложения, а старые удалились:

![workflow_start](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_CICD_workflow_start.png)

![workflow_finished](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_CICD_workflow_finished.png)

![version1_2](https://github.com/A-Tagir/devops-diplom-yandexcloud/blob/main/Diploma_k8s_CICD_version1_2.png)

* Видим, что все работает корректно.
  
* Забыл про поддержку тегов. Доделываю.
* 


Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---

