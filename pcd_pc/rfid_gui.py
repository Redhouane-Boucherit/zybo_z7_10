import tkinter as tk
from tkinter import ttk
import serial
import serial.tools.list_ports
import threading
import time

class RFIDControlApp:
    def __init__(self, root):
        self.root = root
        self.root.title("tagwave RFID Control GUI")
        self.root.geometry("400x350")

        self.ser = None
        self.reading_thread = None
        self.stop_thread = False

        # --- Connection Frame ---
        conn_frame = ttk.LabelFrame(root, text="Connection")
        conn_frame.pack(pady=10, fill="x", padx=10)

        # Dropdown for Ports
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn_frame, textvariable=self.port_var)
        self.port_combo.pack(side="left", padx=5, pady=5, fill="x", expand=True)
        
        # Refresh Button
        ttk.Button(conn_frame, text="Refresh", command=self.refresh_ports).pack(side="left", padx=2)

        # Connect Button
        self.btn_connect = ttk.Button(conn_frame, text="Connect", command=self.toggle_connection)
        self.btn_connect.pack(side="left", padx=5)

        # --- Control Frame ---
        ctrl_frame = ttk.LabelFrame(root, text="Commands")
        ctrl_frame.pack(pady=10, fill="both", expand=True, padx=10)

        # Command Buttons (Mapped to C code '0'-'4')
        ttk.Button(ctrl_frame, text="REQA (26)", command=lambda: self.send_cmd('0')).pack(fill="x", pady=2)
        ttk.Button(ctrl_frame, text="WUPA (52)", command=lambda: self.send_cmd('1')).pack(fill="x", pady=2)
        ttk.Button(ctrl_frame, text="Select (93 20)", command=lambda: self.send_cmd('2')).pack(fill="x", pady=2)
        ttk.Button(ctrl_frame, text="Long Select", command=lambda: self.send_cmd('3')).pack(fill="x", pady=2)
        ttk.Button(ctrl_frame, text="Halt", command=lambda: self.send_cmd('4')).pack(fill="x", pady=2)

        # --- Log Area ---
        self.log_area = tk.Text(root, height=8, state='disabled', bg="#f0f0f0")
        self.log_area.pack(pady=10, padx=10, fill="both")

        # Initial Port Scan
        self.refresh_ports()

    def refresh_ports(self):
        """Scans for available serial ports."""
        ports = [comport.device for comport in serial.tools.list_ports.comports()]
        self.port_combo['values'] = ports
        if ports:
            self.port_combo.current(len(ports)-1) # Select the last one (usually the Zybo UART)
        else:
            self.port_combo.set("No Ports Found")

    def toggle_connection(self):
        """Handles connecting and disconnecting from Serial."""
        if self.ser and self.ser.is_open:
            # Disconnect
            self.stop_thread = True
            if self.reading_thread:
                self.reading_thread.join()
            self.ser.close()
            self.btn_connect.config(text="Connect")
            self.log("Disconnected.")
        else:
            # Connect
            try:
                port = self.port_var.get()
                self.ser = serial.Serial(port, 115200, timeout=1)
                self.btn_connect.config(text="Disconnect")
                self.log(f"Connected to {port}")
                
                # Start reading thread
                self.stop_thread = False
                self.reading_thread = threading.Thread(target=self.read_serial)
                self.reading_thread.daemon = True
                self.reading_thread.start()
            except Exception as e:
                self.log(f"Error: {e}")

    def send_cmd(self, char_cmd):
        """Sends a single character command to the Zybo."""
        if self.ser and self.ser.is_open:
            try:
                self.ser.write(char_cmd.encode())
                self.log(f"Sent Command: {char_cmd}")
            except Exception as e:
                self.log(f"Send Error: {e}")
        else:
            self.log("Not connected!")

    def read_serial(self):
        """Background thread to read data from Zybo."""
        while not self.stop_thread and self.ser and self.ser.is_open:
            try:
                if self.ser.in_waiting > 0:
                    data = self.ser.read().decode(errors='ignore')
                    if data:
                        # Schedule GUI update on main thread
                        self.root.after(0, lambda d=data: self.log(f"Zybo Echo: {d}"))
                else:
                    time.sleep(0.01) # Prevent high CPU usage
            except Exception as e:
                break

    def log(self, msg):
        """Thread-safe logging to the text area."""
        self.log_area.config(state='normal')
        self.log_area.insert(tk.END, msg + "\n")
        self.log_area.see(tk.END)
        self.log_area.config(state='disabled')

if __name__ == "__main__":
    root = tk.Tk()
    app = RFIDControlApp(root)
    root.mainloop()