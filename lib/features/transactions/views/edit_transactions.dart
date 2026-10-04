import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:wallone/features/ads/widgets/banner_ad_widget.dart';
import 'package:wallone/shared/widgets/dropdown_menu.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/transactions/providers/transaction_type_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/features/categories/providers/category_provider.dart';

class EditTransactionPage extends StatefulWidget {
  final AllListProvider transaction;

  const EditTransactionPage({super.key, required this.transaction});

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  final TextEditingController _controller = TextEditingController();

  String? selectedTitle;
  String? selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool dateConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate dropdowns and text field with the current transaction values.
    selectedTitle = widget.transaction.title;
    selectedCategory = widget.transaction.category;
    _controller.text = widget.transaction.amount.toStringAsFixed(2);

    // Set the transaction type based on the existing transaction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionTypeProvider>(context, listen: false)
          .setTransactionType(!widget.transaction.isIncome);
    });

    // Initialize selected date/time from the existing transaction
    try {
      final parsed = DateTime.parse(widget.transaction.date);
      _selectedDate = parsed;
      _selectedTime = TimeOfDay.fromDateTime(parsed);
      dateConfirmed = true;
    } catch (_) {
      _selectedDate = null;
      _selectedTime = null;
      dateConfirmed = false;
    }
  }

  void _showDateTimePicker() {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        final pickerKey = ValueKey(_selectedDate?.millisecondsSinceEpoch ?? 0);
        return Container(
          decoration: BoxDecoration(
            color: mainColor(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Select Date & Time',
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth / 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: primaryColor(context),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date & Time Picker
              CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.outfit(
                      fontSize: screenWidth / 25,
                      color: cardTextColor(context),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: boxColor(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor(context).withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CupertinoDatePicker(
                        key: pickerKey,
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: _selectedDate ?? DateTime.now(),
                        onDateTimeChanged: (DateTime newDateTime) {
                          setModalState(() {
                            _selectedDate = newDateTime;
                            _selectedTime = TimeOfDay.fromDateTime(newDateTime);
                            dateConfirmed = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: boxColor(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor(context).withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.toLocal().toString().split(' ')[0].replaceAll('-', '/')}  ${_selectedTime!.format(context)}'
                                  : 'No date selected',
                              style: GoogleFonts.outfit(
                                fontSize: screenWidth / 30,
                                color: cardTextColor(context),
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: screenWidth / 15,
                            icon: const Icon(Icons.refresh),
                            color: Colors.redAccent,
                            tooltip: 'Reset date & time',
                            onPressed: () {
                              setModalState(() {
                                _selectedDate = null;
                                _selectedTime = null;
                                dateConfirmed = false;
                              });
                              setState(() {
                                _selectedDate = null;
                                _selectedTime = null;
                                dateConfirmed = false;
                              });
                            },
                          ),
                          IconButton(
                            iconSize: screenWidth / 15,
                            icon: Icon(
                              dateConfirmed
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                            ),
                            color: purpleColors(context),
                            onPressed: () {
                              if (_selectedDate != null) {
                                setState(() {
                                  dateConfirmed = true;
                                });
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionTypeProvider =
        Provider.of<TransactionTypeProvider>(context);
    final listProvider = Provider.of<ListProvider>(context, listen: false);
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = intl.NumberFormat.simpleCurrency(name: code).currencySymbol;

    return Scaffold(
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          "Edit Transaction",
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: mainColor(context),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: DropdownMenuDynamicWidget(
                    boxColor: boxColor(context),
                    hintText: "Pay Via",
                    items: const [
                      "Cash",
                      "Card",
                      "Gpay",
                      "PhonePay",
                      "NetBanking"
                    ],
                    onItemSelected: (value) {
                      setState(() {
                        selectedTitle = value;
                      });
                    },
                    value: selectedTitle,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final categories = categoryProvider.categories;
                      return DropdownMenuDynamicWidget(
                        boxColor: boxColor(context),
                        hintText: "Type",
                        items: categories.map((c) => c.name).toList(),
                        onItemSelected: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        value: selectedCategory,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                transactionTypeProvider.toggleTransactionType();
              },
              child: Text(
                transactionTypeProvider.isExpensesSelected
                    ? "Expenses"
                    : "Income",
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final textSize = (TextPainter(
                  text: TextSpan(
                    text: _controller.text.isEmpty ? "0" : _controller.text,
                    style: GoogleFonts.outfit(
                      fontSize: 70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                )..layout())
                    .size;
                final fieldWidth = textSize.width + 5;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      symbol,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: purpleColors(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 70,
                          color: primaryColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "0",
                          hintStyle: TextStyle(
                            color: primaryColor(context),
                          ),
                          border: InputBorder.none,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}$')),
                          LengthLimitingTextInputFormatter(7),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date & Time picker button
                  GestureDetector(
                    onTap: _showDateTimePicker,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: inversePrimaryColor(context),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              color: shadowColor(context),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: primaryColor(context),
                        ),
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      final submittedAmount =
                          double.tryParse(_controller.text) ?? 0;

                      if (submittedAmount > 0 &&
                          selectedTitle != null &&
                          selectedCategory != null) {
                        final isIncome =
                            !transactionTypeProvider.isExpensesSelected;

                        DateTime createdDate;
                        if (_selectedDate != null) {
                          final t = _selectedTime ??
                              TimeOfDay.fromDateTime(DateTime.now());
                          createdDate = DateTime(
                            _selectedDate!.year,
                            _selectedDate!.month,
                            _selectedDate!.day,
                            t.hour,
                            t.minute,
                          );
                        } else {
                          createdDate = DateTime.parse(widget.transaction.date);
                        }

                        // Create an updated transaction with the new values.
                        final updatedTransaction = AllListProvider(
                          id: widget.transaction.id,
                          title: selectedTitle!,
                          category: selectedCategory!,
                          amount: submittedAmount,
                          isIncome: isIncome,
                          date: createdDate.toIso8601String(),
                          transactionType: isIncome
                              ? TransactionType.income
                              : TransactionType.expense,
                        );

                        listProvider.editTransaction(updatedTransaction);
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              submittedAmount <= 0
                                  ? "Please enter a valid amount."
                                  : "Please select all fields.",
                              style: GoogleFonts.outfit(fontSize: 16),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: inversePrimaryColor(context),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              color: shadowColor(context),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: BannerAdWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
