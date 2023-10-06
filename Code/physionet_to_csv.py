import os

def convert_psv_to_csv(input_folder, output_file):
    with open(output_file, 'w') as out_csv:
        first_file = True
        for filename in os.listdir(input_folder):
            if filename.endswith('.psv'):
                patient_id = filename.rsplit('.', 1)[0]  # Entferne die .psv-Endung
                with open(os.path.join(input_folder, filename), 'r') as in_psv:
                    # Wenn es die erste Datei ist, schreibe den Header in die CSV
                    if first_file:
                        header = in_psv.readline().strip()
                        out_csv.write(f"Patient_ID,{header.replace('|', ',')}\n")
                        first_file = False
                    else:
                        # Überspringe den Header für nachfolgende Dateien
                        in_psv.readline()
                    
                    # Schreibe den Rest der Datei in die CSV, füge Patient_ID hinzu
                    for line in in_psv:
                        out_csv.write(f"{patient_id},{line.replace('|', ',')}")

    print(f"Dateien aus {input_folder} wurden in {output_file} kombiniert.")

def main():
    folder1_path = './Data/training/'
    folder2_path = './Data/training_setB/'
    output_csv1 = 'folder1_data.csv'
    output_csv2 = 'folder2_data.csv'

    convert_psv_to_csv(folder1_path, output_csv1)
    convert_psv_to_csv(folder2_path, output_csv2)

if __name__ == "__main__":
    main()


# # Ordnernamen und Ausgabedatei angeben
# folder1_path = './Data/training/'
# folder2_path = './Data/training_setB/'
# output_csv = './Data/Physionet-Challenge/combined_data.csv'

# combine_folders_to_csv(folder1_path, folder2_path, output_csv)
