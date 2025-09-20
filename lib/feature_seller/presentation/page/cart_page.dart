import 'package:flutter/material.dart';

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cart = [];

  @override
  void initState() {
    super.initState();
    // مثال: إضافة منتجات تجريبية
    cart.add({
      'product': {'name': 'منتج 1', 'quantity': 10},
      'qty': 1,
      'controller': TextEditingController(text: "1"),
    });
    cart.add({
      'product': {'name': 'منتج 2', 'quantity': 5},
      'qty': 1,
      'controller': TextEditingController(text: "1"),
    });
  }

  void increaseQty(int i) {
    final p = cart[i]['product'];
    if (cart[i]['qty'] < p['quantity']) {
      setState(() {
        cart[i]['qty'] += 1;
        cart[i]['controller'].text = cart[i]['qty'].toString();
      });
    }
  }

  void decreaseQty(int i) {
    if (cart[i]['qty'] > 1) {
      setState(() {
        cart[i]['qty'] -= 1;
        cart[i]['controller'].text = cart[i]['qty'].toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("السلة")),
      body: ListView.builder(
        itemCount: cart.length,
        itemBuilder: (context, i) {
          final p = cart[i]['product'];

          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text(p['name']),
              subtitle: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () => decreaseQty(i),
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: cart[i]['controller'],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          Future.microtask(
                            () => setState(() => cart[i]['qty'] = 1),
                          );
                          return;
                        }
                        final newQty = int.tryParse(value);
                        if (newQty == null || newQty <= 0) {
                          Future.microtask(
                            () => setState(() => cart[i]['qty'] = 1),
                          );
                          cart[i]['controller'].text = "1";
                        } else if (newQty > p['quantity']) {
                          Future.microtask(
                            () =>
                                setState(() => cart[i]['qty'] = p['quantity']),
                          );
                          cart[i]['controller'].text = p['quantity'].toString();
                        } else {
                          setState(() => cart[i]['qty'] = newQty);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => increaseQty(i),
                  ),
                ],
              ),
              trailing: Text("الكمية: ${cart[i]['qty']}"),
            ),
          );
        },
      ),
    );
  }
}
