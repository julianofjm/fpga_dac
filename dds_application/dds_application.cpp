//	C plus plus application to control the frequencies in the 
//	fpga-dac project. It uses a serial stream communication.
//	Juliano Murari (LNLS)	- March 2014

#include <SerialStream.h>
#include <iostream>
#include <string>
#include <cstring>
#include <string.h>
#include <cstdlib>
#include <stdlib.h>
#include <unistd.h>

#define CLK_SYS	100		// System clock [MHz]

using namespace LibSerial ;

// This function returns queued data on port, returns empty string if there is no data
// does not block
std::string read(SerialStream& serial_port)
{
     std::string result;
     while( serial_port.rdbuf()->in_avail() )
     {
         char next_byte;
         serial_port.get(next_byte);  
         result.append(1, next_byte);
     }
     if (result.length() < 2) {
		return "NULL";
	 }	
     else{
		return result;
	}
}

// Function that write a string on serial port
void write(SerialStream& serial_port, const std::string& data)
{
    serial_port.write(data.c_str(), data.size());
}

std::string get_output_frequency(int f)
{
		int phase_inc;
		std::string result("w 00880001 ");
		char aux[9];

		phase_inc = (f * 4294967295) / (CLK_SYS*1000000);
		sprintf(aux, "%.8x ", phase_inc);

		result.append(aux);
		result.append(" \r");
	
		return result;	
}

std::string get_output_wait_frequency(int f)
{
		int count;
		std::string result("w 00880000 ");
		char aux[9];

		count = (CLK_SYS*1000) / f;
		sprintf(aux, "%.8x ", count);

		result.append(aux);
		result.append(" \r");
	
		return result;	
}

int main()
{
	SerialStream my_serial_stream ;										// Create a SerialStream instance.
	
	my_serial_stream.Open( "/dev/ttyUSB0" ) ;							// Open the serial port for communication.
	if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't open RS-232 port. Maybe you did not run as sudo?" << std::endl ;
		exit(1) ;
	}

	//~ my_serial_stream.SetBaudRate( SerialStreamBuf::BAUD_115200 ) ;	// Set BAUD RATE
	//~ my_serial_stream.SetBaudRate( SerialStreamBuf::BAUD_57600 ) ;	// It didnt work for dds application
	my_serial_stream.SetBaudRate( SerialStreamBuf::BAUD_9600 ) ;
	if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't set transmission speed" << std::endl ;
		exit(1) ;
	}

	// Use 8 bit wide characters. 
	my_serial_stream.SetCharSize( SerialStreamBuf::CHAR_SIZE_8 ) ;
	if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't set number of bits" << std::endl ;
		exit(1) ;
	}

	// Use one stop bit. 
	my_serial_stream.SetNumOfStopBits(1) ;
		if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't set number of stop bits" << std::endl ;
		exit(1) ;
	}

	// Use odd parity during serial communication. 
	my_serial_stream.SetParity( SerialStreamBuf::PARITY_NONE ) ;
	//~ my_serial_stream.SetParity( SerialStreamBuf::PARITY_ODD ) ;
	if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't set parity bit" << std::endl ;
		exit(1) ;
	}

	// Use hardware flow-control. 
	my_serial_stream.SetFlowControl( SerialStreamBuf::FLOW_CONTROL_NONE ) ;
	//~ my_serial_stream.SetFlowControl( SerialStreamBuf::FLOW_CONTROL_HARD ) ;
	if ( ! my_serial_stream.good() )
	{
		std::cout << "RS232_syscon: Error - can't set flow control (handshaking)" << std::endl ;
		exit(1) ;
	}

	std::cout << "Starting...\n" << std::endl;

	int TIME = 100000;			// time microseconds
	std::string reply;
	std::string reset("i \r");
	std::string f_din_s, f_wait_s;
	int f_din, f_wait;
	
	do{
		std::cout << "Enter the sinusoid frequency (1 to 1.000.000 [Hz]):" << std::endl ;
		scanf ("%d",&f_din);
	}while(f_din<1 || f_din>1000000);
	
	do{
		std::cout << "Enter the wait frequency (1 to 1350 [kHz]):" << std::endl ;
		scanf ("%d",&f_wait);
	}while(f_wait<1 || f_wait>1350);
	
	f_din_s = get_output_frequency(f_din);
	f_wait_s = get_output_wait_frequency(f_wait);

	std::cout << "Resetting:	" << reset << std::endl ;
	write(my_serial_stream, reset);
	usleep(TIME);
	reply = read(my_serial_stream);
	std::cout << reply << std::endl;

	std::cout << "Data in frequency command:	" << f_din_s << std::endl ;
	write(my_serial_stream, f_din_s);
	usleep(TIME);
	reply = read(my_serial_stream);
	std::cout << reply << std::endl;

	std::cout << "Wait frequency command:	" << f_wait_s << std::endl ;
	write(my_serial_stream, f_wait_s);
	usleep(TIME);
	reply = read(my_serial_stream);
	std::cout << reply << std::endl;

	// Closing the serial port
	my_serial_stream.Close() ;
}
