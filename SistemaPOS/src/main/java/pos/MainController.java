package pos;

import javafx.collections.*;
import javafx.event.ActionEvent;
import javafx.fxml.FXML;
import javafx.fxml.FXMLLoader;
import javafx.scene.Node;
import javafx.scene.control.*;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.StackPane;
import pos.model.OrderLine;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class MainController {

    @FXML private Label lblFecha, lblTotal, lblTotalHeader;
    @FXML private TableView<OrderLine> tblPedido;
    @FXML private TableColumn<OrderLine, Number> colItem, colCant, colPrecio, colTotal;
    @FXML private TableColumn<OrderLine, String> colNombre;
    @FXML private FlowPane menuGrid;
    @FXML private StackPane contentPane;

    private final ObservableList<OrderLine> pedido = FXCollections.observableArrayList();
    private final Map<String, Double> precios = new LinkedHashMap<>();

    private String keypadBuffer = "";

    @FXML
    public void initialize() {
        // columnas
        colItem.setCellValueFactory(c -> c.getValue().itemProperty());
        colNombre.setCellValueFactory(c -> c.getValue().nombreProperty());
        colCant.setCellValueFactory(c -> c.getValue().cantidadProperty());
        colPrecio.setCellValueFactory(c -> c.getValue().precioProperty());
        colTotal.setCellValueFactory(c -> c.getValue().totalProperty());
        tblPedido.setItems(pedido);

        // fecha/header
        lblFecha.setText("FECHA: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("EEE dd MMM hh:mm a")));
        actualizarTotal();

        // precios demo (puedes traerlos de BD)
        precios.put("SOPA", 5.00);
        precios.put("CREMA", 6.50);
        precios.put("ENTRADAS", 0.00);
        precios.put("MENÚ 8 SOLES", 8.00);
        precios.put("MILANESA C/ PAPAS FRITAS", 12.00);
        precios.put("POLLO PARRILLERO", 13.00);
        precios.put("TRUCHA FRITA", 15.00);
        precios.put("LOMO SALTADO", 14.00);
        precios.put("CEVICHE CLÁSICO", 18.00);
        precios.put("AJÍ DE GALLINA", 10.00);
        precios.put("ARROZ CON POLLO", 10.00);
        precios.put("TALLARÍN SALTADO", 12.00);

        // construir grilla de botones
        precios.keySet().forEach(this::agregarBotonPlato);
    }

    private void agregarBotonPlato(String nombre) {
        Button b = new Button(nombre);
        b.setMinSize(160, 54);
        b.setStyle("-fx-background-radius:12; -fx-font-weight:bold; -fx-background-color:#4DD07E; -fx-text-fill:white;");
        b.setOnAction(e -> agregarAlPedido(nombre));
        menuGrid.getChildren().add(b);
    }

    private void agregarAlPedido(String nombre) {
        double precio = Optional.ofNullable(precios.get(nombre)).orElse(0.0);
        // si ya existe, incrementa cantidad
        for (OrderLine ol : pedido) {
            if (ol.getNombre().equals(nombre)) {
                ol.incCantidad(1);
                tblPedido.refresh();
                actualizarTotal();
                return;
            }
        }
        int nextItem = pedido.size() + 1;
        pedido.add(new OrderLine(nextItem, nombre, 1, precio));
        actualizarTotal();
    }

    private void actualizarTotal() {
        double total = pedido.stream().mapToDouble(OrderLine::getTotal).sum();
        String txt = String.format("S/ %.2f", total);
        lblTotal.setText(txt);
        lblTotalHeader.setText(txt);
    }

    // ====== Keypad ======
    @FXML private void onKey(ActionEvent e) {
        String v = ((Button)e.getSource()).getText();
        keypadBuffer += v;
    }
    @FXML private void onBorra() { keypadBuffer = ""; }
    @FXML private void onOk() {
        // aplica el buffer como cantidad a la fila seleccionada
        OrderLine sel = tblPedido.getSelectionModel().getSelectedItem();
        if (sel != null && !keypadBuffer.isBlank()) {
            try {
                double qty = Double.parseDouble(keypadBuffer);
                if (qty >= 0) sel.setCantidad(qty);
                sel.setTotal(sel.getCantidad() * sel.getPrecio());
                tblPedido.refresh();
                actualizarTotal();
            } catch (NumberFormatException ignored) {}
        }
        keypadBuffer = "";
    }
    @FXML private void onEnter() { onOk(); }

    // ====== Navegación interna (StackPane) ======
    @FXML private void onElegirCliente() {
        try {
            FXMLLoader l = new FXMLLoader(getClass().getResource("/pos/ClienteView.fxml"));
            Node cliente = l.load();
            ClienteController cc = l.getController();
            cc.setOnClose(() -> showMenu());
            // podrías pasar callback onSelect para asociar el cliente seleccionado
            contentPane.getChildren().setAll(cliente);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private void showMenu() {
        // reconstruye vista de menú dentro del StackPane
        contentPane.getChildren().setAll(new ScrollPane(menuGrid));
    }

    @FXML private void onCerrar() { ((Node)lblFecha).getScene().getWindow().hide(); }
}
