/*
+------------------------------------------------------------------+
|                                                                  |
|                                        Viking's Multi Hedging EA |
|                                                      Version 0.1 |
|                            Code Copyright © 2013 Stoill Barzakov |
|                                             http://www.m0rd0r.eu |
|                                                                  |
|                Original idea by Michael Norse's Greenland system |
|                          /Coded with his permision and guidance/ |
|                                                                  |
+------------------------------------------------------------------+
|                                                                  |
|  Drop on any timeline or currency pair                           |
|                                                                  |
|  This EA does not make difference between 1m or 30m              |
|                                                                  |
|  It works on any time frame                                      |
|                                                                  |
|  This is a very high drawdown system, which takes quite a lot of |
|   time to build up and start making profits. It is a slow system |
|                                so take your time and be patient. |
|                                                                  |
+------------------------------------------------------------------+
*/

// necessary header file for standard errors.
#include <stdlib.mqh>

// Some useless properties, MQH file above will overwrite them.
#property copyright "Stoill Barzakov"
#property      link "www.m0rd0r.eu"

// define retries, delays and other constants.
#define		COMMIT_RETRIES		10
#define		COMMIT_DELAY		500
#define		LONG			1
#define		SHORT			-1
#define		ALL			0

// Globals
extern   int	AggresiveHedge		=  0;		// Will hedge the opposite ammount of lots minus the already open lots.
							// Aggresive = 0: Will always use the initial lot size to open new positions
							// Aggresive = 1: If you have 6 longs and 1 short, this will open next short order
							//			at InitialLots x5
							// Aggresive = 2: If you have 6 longs sized total 3 lots and 1 short worth 0.10 lots
							// 			this will open next short order the size of 
							//			3 lots to cover the longs
extern   int	MagicNumber		=  4400;	// Pazardjik's postal code in Bulgaria :P
extern   double	InitialLots		=  0.01;	// This will be multiplied by the aggresive hedging alogrithm if necessary
extern   int	PipsPerStep		=  200;		// This will establish the distance between each step in PIPs.

extern   bool	LogMessages		=  true;
extern   bool	FiveDigits		=  true;

// Some temp params needed to be globals as well.
int		Normalizator;
double		point;
int		Slippage 		=  3;		// 3 is not always acceptable, but will do in stronger trends.
bool		successfullTrade	=  false;
bool            check;

// Order count
double
		lots_Long,
		lots_Short;
int
		orders_Long,
		orders_Short;

// More temp params.
double 		totalPL,
		totalSwap,
		order_minimal,
		order_maximal,
		maximal_short,
		minimal_long;

int init() {
	if (FiveDigits == false) { point = Point; Normalizator = 1000;}
	if (FiveDigits == true) { point = 10 * Point; Normalizator = 10000;}
	return(0);
}

int deinit() { return(0); }

int start() { 

	double lots = InitialLots;
	double longDelta, shortDelta;
	double longPipDistance, shortPipDistance;
	
	double currentPrice = MarketInfo(Symbol(),MODE_BID);
	int orders_Total = CountOrders();

	// Check if we are just starting and place positions
	if( orders_Total == 0) {
      
		check = CreatePendingOrders(LONG, OP_BUY, Ask, lots, 0, PipsPerStep, "");
		check = CreatePendingOrders(SHORT, OP_SELL, Bid, lots, 0, PipsPerStep, "");
	}

	orders_Total = CountOrders();

	// We have open positions already. Check if we need more per direction.
	if( orders_Total > 0) {
		longDelta = (minimal_long - currentPrice);
		shortDelta = (currentPrice - maximal_short);
		longPipDistance = longDelta * Normalizator;
		shortPipDistance = shortDelta * Normalizator;
		if ((longPipDistance > PipsPerStep) || orders_Long == 0) {
			if (AggresiveHedge == 0) {lots = InitialLots;}
			if (AggresiveHedge == 1) {lots = orders_Short * InitialLots;}
			if (AggresiveHedge == 2) {lots = lots_Short;}
			check = CreatePendingOrders(LONG, OP_BUY, Ask, lots, 0, PipsPerStep, ""); 
		}
		if ((shortPipDistance > PipsPerStep) || orders_Short == 0) {
			if (AggresiveHedge == 0) {lots = InitialLots;}
			if (AggresiveHedge == 1) {lots = orders_Long * InitialLots;}
			if (AggresiveHedge == 2) {lots = lots_Long;}			
			check = CreatePendingOrders(SHORT, OP_SELL, Bid, lots, 0, PipsPerStep, "");
		}
	}
	
	// Show what's open and what is the profit in the top-left corner.
	if (LogMessages) {
		longDelta = (currentPrice - order_maximal);
		shortDelta = (order_minimal - currentPrice);
		string info = "Broker: " + AccountCompany() +
			"\nTotal long orders:" + orders_Long +
			"\nLong order lots:" + lots_Long +
			"\nHighest long:" + order_maximal +
			"\nDelta long:" + longDelta +
			"\nTotal short orders:" + orders_Short +
			"\nShort order lots:" + lots_Short +
			"\nLowest short:" + order_minimal +
			"\nDelta short:" + shortDelta +
			"\nTotal profit:" + DoubleToStr(totalPL, 2) +
			"\nTotal Swap:" + DoubleToStr(totalSwap, 2);
		Comment (info);
		//Print (info);
	}
	Sleep(5000);
        return (0);
}

int CountOrders() {

	int count = 0;
	totalPL = 0;
	totalSwap = 0;
	orders_Short = 0;
	orders_Long = 0;
	lots_Long = 0;
	lots_Short = 0;
	order_minimal = 9999.9;
	order_maximal = 0;
	maximal_short = 0;
	minimal_long = 9999.9;
  
	for( int i = OrdersTotal() - 1; i >= 0; i--) {
	
		check = OrderSelect( i, SELECT_BY_POS);
		
		if( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) {
		
			count++;
			totalPL += OrderProfit();

			if( OrderType() == OP_BUY ) { 
				orders_Long++;
				lots_Long += OrderLots();
				if (OrderOpenPrice()  > order_maximal) {
					order_maximal = OrderOpenPrice();
				}
				if (OrderOpenPrice()  < minimal_long) {
					minimal_long  = OrderOpenPrice();
				}
			}
			if( OrderType() == OP_SELL ) {
				orders_Short++;
				lots_Short += OrderLots();
				if (OrderOpenPrice()  < order_minimal) {
					order_minimal = OrderOpenPrice();
				}
				if (OrderOpenPrice()  > maximal_short) {
					maximal_short = OrderOpenPrice();
				}
			}
		}
	}
	totalSwap = GetCurrentSwap();
	return( count );
}

double CheckLots(double lots)
{
	double lot, lotmin, lotmax, lotstep, margin;
    
	lotmin = MarketInfo(Symbol(), MODE_MINLOT);
	lotmax = MarketInfo(Symbol(), MODE_MAXLOT);
	lotstep = MarketInfo(Symbol(), MODE_LOTSTEP);
	margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);

	if (lots*margin > AccountFreeMargin()) lots = AccountFreeMargin() / margin;

	lot = MathFloor(lots/lotstep + 0.5) * lotstep;

	if (lot < lotmin) lot = lotmin;
	if (lot > lotmax) lot = lotmax;

	return (lot);
}

void ExitAll(int direction) {

	for (int i = 0; i <= OrdersTotal(); i++) {
		check = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

		if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
			if (OrderType() == OP_BUY && direction == LONG) 
				{ Exit(OrderTicket(), LONG, OrderLots(), Blue); }
			if (OrderType() == OP_SELL && direction == SHORT)
				{ Exit( OrderTicket(), SHORT, OrderLots(), Red); }
		}
	}
}

bool Exit(int ticket, int dir, double volume, color clr, int t = 0)  {

	int i, j;
	double prc;
	string cmt;

	bool closed;

	if (LogMessages == true)
		{Print("Exit(" + dir + "," + DoubleToStr(volume,3) + "," + t + ")");}

	for (i=0; i<COMMIT_RETRIES; i++) {
		for (j=0; (j<50) && IsTradeContextBusy(); j++) Sleep(100);
		RefreshRates();

		if (dir == LONG) {
			prc = Bid;
		}

		if (dir == SHORT) {
			prc = Ask;
		}
		
		if (LogMessages == true)
			{ Print("Exit: price = " + DoubleToStr(prc,Digits));}

		closed = OrderClose(ticket,volume,prc,Slippage,clr);
		
		if (closed) {
			if (LogMessages == true) {Print("Trade closed");}

			return (true);
		}

		if (LogMessages == true) {
			Print("Exit: error \'" +
			ErrorDescription(GetLastError()) + 
			"\' when exiting with " + 
			DoubleToStr(volume,3) + 
			" @"+DoubleToStr(prc,Digits));
		}
		
		Sleep(COMMIT_DELAY);
	}

	if (LogMessages == true) {Print("Exit: can\'t enter after " + COMMIT_RETRIES + " retries");}
	return (false);
}

double GetCurrentPL () {

	double currentPL = 0;
	

	for( int i = 0; i <= OrdersTotal(); i++) {

		check = OrderSelect( i, SELECT_BY_POS, MODE_TRADES);

		if( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) {
			currentPL += OrderProfit();
		}
	}

	return( currentPL );
}

double GetCurrentSwap () {

	double currentSwap = 0;

	for( int i = 0; i <= OrdersTotal(); i++) {

		check = OrderSelect( i, SELECT_BY_POS, MODE_TRADES);

		if( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) {
			currentSwap += OrderSwap();
		}
	}

	return( currentSwap );
}

bool CreatePendingOrders(int dir, int pendingType, double entryPrice, double volume, int stop, int take, string comment)  {

	double sl, tp;

	int retVal = 0;

	double lots = CheckLots(volume);
	string info;
   
	for ( int i = 0; i < COMMIT_RETRIES; i++) {

		for ( int j = 0; ( j < 50 ) && IsTradeContextBusy(); j++) {
			Sleep(100);
			// Let's hope whatever script grabbed the pair's window will drop it in 5 seconds.
		}

		RefreshRates();

		switch(dir)  {
			case LONG:
				if (stop != 0) { sl = entryPrice-(stop*point); }
				else { sl = 0; }
				if (take != 0) { tp = entryPrice +(take*point); }
				else { tp = 0; }
                
				if (LogMessages == true) {
					info = "Type: " + pendingType + 
					",\nentryPrice: " + DoubleToStr(entryPrice, Digits) + 
					",\nAsk " + DoubleToStr(Ask,Digits) +
					",\nLots " + DoubleToStr(lots, 2) + 
					",\nStop: " + DoubleToStr(sl, Digits) +
					",\nTP: " + DoubleToStr(tp, Digits);
					Print(info);
					Comment(info);
				}

				retVal = OrderSend(Symbol(), pendingType, lots, entryPrice, Slippage, sl, tp, comment, MagicNumber, 0, Blue);
				break;

			case SHORT:
				if (stop != 0) { sl = entryPrice+(stop*point); }
				else { sl = 0; }
				if (take != 0) { tp = entryPrice-(take*point); }
				else { tp = 0; }

				if (LogMessages == true) {
					info = "Type: " + pendingType + 
					",\nentryPrice: " + DoubleToStr(entryPrice, Digits) +
					",\nBid " + DoubleToStr(Bid,Digits) +
					",\nLots " + DoubleToStr(lots, 2) +
					",\nStop: " + DoubleToStr(sl, Digits) +
					",\nTP: " + DoubleToStr(tp, Digits);
					Print(info);
					Comment(info);
				}
          
				retVal = OrderSend(Symbol(), pendingType, lots, entryPrice, Slippage, sl, tp, comment, MagicNumber, 0, Red);
				break;
		}
           
		if( retVal > 0 ) { return( true ); }
			else {
				// Something nasty happened. Warn the user.
				Print("CreatePendingOrders: error \'" +
				ErrorDescription(GetLastError()) + 
				"\' when setting entry order");
				Sleep(COMMIT_DELAY);
			}
	}
   
	return( false );
}