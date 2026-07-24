#include <iostream>
#include <string>
using namespace std;

// -------------------- Structs --------------------
struct Student {
    string rollno;
    int busno;
    int stopID;              // 0,1,2
    bool nextSlotPriority;
};

struct Bus {
    string busNumber;
    int capacity;
    int currentStudentCount;
    string route;
};

// -------------------- Buffer Bus Function --------------------
void bufferbus(int stopLeft[]) {
    int maxStop = 0;

    for (int i = 1; i < 3; i++) {
        if (stopLeft[i] > stopLeft[maxStop]) {
            maxStop = i;
        }
    }

    if (stopLeft[maxStop] >= 5) {
        cout << "Buffer bus sent to stop " << maxStop << endl;
    }
}

// -------------------- Main --------------------
int main() {

    Bus buses[3];
    Student students[20];

    int leftbehind = 0;
    int stopLeft[3] = {0, 0, 0};

    // -------- Initialize buses --------
    buses[0] = {"Bus 1", 10, 0, "Jamalpur ---- Model Town"};
    buses[1] = {"Bus 2", 5, 0, "Bole -------- GTS"};
    buses[2] = {"Bus 3", 15, 0, "Kuchairy ------- Shadman"};

    cout << "--------- Select Bus Number -------------\n";
    cout << "1: Jamalpur --------- Model Town\n";
    cout << "2: Bole     --------- GTS\n";
    cout << "3: Kuchairy --------- Shadman\n\n";

    // -------- Student input --------
    for (int i = 0; i < 20; i++) {

        students[i].nextSlotPriority = false;

        cout << "\nEnter roll no: ";
        cin >> students[i].rollno;

        cout << "Enter Bus Number: ";
        cin >> students[i].busno;

        students[i].stopID = students[i].busno - 1;

        int b = students[i].busno - 1;

        if (b >= 0 && b < 3) {

            if (buses[b].currentStudentCount < buses[b].capacity) {
                cout << buses[b].busNumber << endl;
                cout << buses[b].route << endl;
                cout << "Spot reserved\n";
                buses[b].currentStudentCount++;
            } else {
                cout << "Bus full ? Priority next time\n";
                students[i].nextSlotPriority = true;
                leftbehind++;
                stopLeft[students[i].stopID]++;
            }

        } else {
            cout << "Invalid bus number\n";
        }
    }

    // -------- Buffer bus decision --------
    bufferbus(stopLeft);

    // -------- Summary --------
    cout << "\n------ SUMMARY ------\n";
    cout << "Model Town left: " << stopLeft[0] << endl;
    cout << "GTS left: " << stopLeft[1] << endl;
    cout << "Shadman left: " << stopLeft[2] << endl;
    cout << "Total left behind: " << leftbehind << endl;

    return 0;
}
