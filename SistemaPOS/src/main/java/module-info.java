module pos {
    requires javafx.controls;
    requires javafx.fxml;

    opens pos to javafx.fxml;
    opens pos.model to javafx.base;
    exports pos;
}
