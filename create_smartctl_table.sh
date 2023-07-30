create_smartctl_table.sh
#!/bin/bash

# Получаем список дисков размером 2.7T
disks=($(lsblk | grep "2,7T" | grep "disk" | sed 's/ .*//g'))

# Функция для получения значения атрибута из вывода smartctl
get_attribute_value() {
  local disk="$1"
  local attribute_id="$2"
  smartctl -A -d sat "/dev/$disk" | awk -v id="$attribute_id" '$1 == id {print $2, $NF}'
}

# Создаем директорию /tmp/smart, если она не существует
mkdir -p /tmp/smart

# Обработка каждого диска
for disk in "${disks[@]}"; do
  # Получаем список уникальных атрибутов
  unique_attributes=($(smartctl -A -d sat "/dev/$disk" | awk 'NR > 7 {print $1}' | uniq))

  # Создаем ассоциативный массив для хранения значений атрибутов
  declare -A attributes_values

  # Заполняем массив данными из первого диска
  for attribute_id in "${unique_attributes[@]}"; do
    attributes_values["$attribute_id"]=$(get_attribute_value "$disk" "$attribute_id")
  done

  # Сохраняем данные в JSON файл
  json_file="/tmp/smart_${disk}.json"
  echo "{" > "$json_file"
  for attribute_id in "${unique_attributes[@]}"; do
    attribute_name=$(echo "${attributes_values[$attribute_id]}" | awk '{print $1}')
    attribute_value=$(echo "${attributes_values[$attribute_id]}" | awk '{print $NF}')
    echo "  \"$attribute_name\": \"$attribute_value\"," >> "$json_file"
  done
  # Удаляем последнюю запятую в файле JSON
  sed -i '$ s/.$//' "$json_file"
  echo "}" >> "$json_file"
done

# Get the list of JSON files matching the pattern
json_files=(/tmp/smart_sd*.json)

# Extract disk names from the file names
disk_names=()
for file in "${json_files[@]}"; do
  disk_name=$(basename "$file" | sed 's/^smart_//; s/\.json$//')
  disk_names+=("$disk_name")
done

# Function to read the attribute values from a JSON file
read_attribute_values() {
  local file="$1"
  jq -r '. | to_entries | .[] | "\(.key) \(.value)"' "$file"
}

# Create an associative array to store attribute values for each disk
declare -A attributes_summary

# Loop through the JSON files and populate the summary table
for file in "${json_files[@]}"; do
  while read -r line; do
    attribute=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{print $2}')
    attributes_summary["$attribute"]+=" $value"
  done < <(read_attribute_values "$file")
done

# Print the summary table
header="attribute ${disk_names[*]}"
echo "$header" | tr ' ' '\t'

for attribute in "${!attributes_summary[@]}"; do
  values="${attributes_summary[$attribute]}"
  echo "$attribute$values" | tr ' ' '\t'
done

