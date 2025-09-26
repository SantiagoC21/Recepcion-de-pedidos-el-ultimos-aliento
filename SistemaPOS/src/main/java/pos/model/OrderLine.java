package pos.model;

import javafx.beans.property.*;

public class OrderLine {
    private final IntegerProperty item = new SimpleIntegerProperty();
    private final StringProperty nombre = new SimpleStringProperty();
    private final DoubleProperty cantidad = new SimpleDoubleProperty();
    private final DoubleProperty precio = new SimpleDoubleProperty();
    private final DoubleProperty total = new SimpleDoubleProperty();

    public OrderLine(int item, String nombre, double cantidad, double precio) {
        setItem(item); setNombre(nombre); setCantidad(cantidad); setPrecio(precio);
        setTotal(cantidad * precio);
    }

    public void incCantidad(double by) { setCantidad(getCantidad() + by); setTotal(getCantidad() * getPrecio()); }

    // getters/setters properties
    public int getItem() { return item.get(); }
    public void setItem(int v) { item.set(v); }
    public IntegerProperty itemProperty() { return item; }

    public String getNombre() { return nombre.get(); }
    public void setNombre(String v) { nombre.set(v); }
    public StringProperty nombreProperty() { return nombre; }

    public double getCantidad() { return cantidad.get(); }
    public void setCantidad(double v) { cantidad.set(v); }
    public DoubleProperty cantidadProperty() { return cantidad; }

    public double getPrecio() { return precio.get(); }
    public void setPrecio(double v) { precio.set(v); }
    public DoubleProperty precioProperty() { return precio; }

    public double getTotal() { return total.get(); }
    public void setTotal(double v) { total.set(v); }
    public DoubleProperty totalProperty() { return total; }
}
